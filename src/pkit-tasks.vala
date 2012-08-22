/* pkit-tasks.vala - Perform tasks on native package-db using PackageKit
 *
 * Copyright (C) 2011-2012 Matthias Klumpp <matthias@tenstral.net>
 *
 * Licensed under the GNU Lesser General Public License Version 3
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;
using Gee;
using Listaller;
using Listaller.Utils;

namespace Listaller {

/**
 * Generate a PackageKit package-id for this application
 */
public string app_item_build_pk_package_id (AppItem app) {
	string data;
	string package_id;
	data = "local:listaller%" + app.desktop_file;

	package_id = PackageKit.Package.id_build (app.idname, app.version, "current", data);

	return package_id;
}

} // End of namespace: Listaller

namespace Listaller.Dep {

private errordomain PkError {
	TRANSACTION_FAILED;
}

/**
 * Abstract class which defines basic things needed by Listaller
 * to access bother PackageKit via DBus when running as user and
 * PackageKit internal API when running as root (and as plugin)
 */
private abstract class PkListallerTask : MessageObject {
	protected Listaller.Config conf;
	protected PackageKit.Task? pktask;
	protected PkBackendProxy? pkbproxy;

	public ErrorItem? last_error { get; set; }

	private new void emit_error (ErrorItem item) { }

	public PkListallerTask (Listaller.Config liconf) {
		base ();
		conf = liconf;

		pkbproxy = null;
		pktask = null;
		if (packagekit_daemon_caller) {
			// Access to the native PackageKit backend
			pkbproxy = get_pk_backend ();
			if (pkbproxy == null) {
				// We don't have a PK backend! This must not happen, if we run as root.
				var msg = _("Could not obtain a PkBackendProxy instance. Maybe the Listaller-PkPlugin is not installed or broken?");
				set_error (ErrorEnum.UNKNOWN, msg);
				critical (msg);
			}
		}
	}

	protected void reset () {
		last_error = null;
		if (pkbproxy == null)
			pktask = new PackageKit.Task ();
	}

	protected void set_error (ErrorEnum id, string details) {
		// Construct error
		ErrorItem item = new ErrorItem (id);
		item.details = details;
		last_error = item;
		debug ("PkResolver: <error> %s", details);
	}
}

private class PkResolver : PkListallerTask {

	public PkResolver (Listaller.Config liconf) {
		base (liconf);
		set_error_hint_str ("PkResolver");
		reset ();
	}

	private void pkit_progress_cb (PackageKit.Progress progress, PackageKit.ProgressType type) {
		// TODO
	}

	private PackageKit.PackageSack? pkit_pkgs_from_depfiles (IPK.Dependency dep) {
		PackageKit.Bitfield filter = PackageKit.filter_bitfield_from_string ("arch;");

		// We only resolve libraries at time
		// TODO: Resolve other dependencies too
		string[] libs = {};
		foreach (string s in dep.raw_complist) {
			if (dep.component_get_type (s) == Dep.ComponentType.SHARED_LIB)
				libs += dep.component_get_name (s);
		}
		libs += null;

		PackageKit.Results? res;
		PackageKit.PackageSack? sack;

		if (pkbproxy == null) {
			try {
				res  = pktask.what_provides (filter, PackageKit.Provides.SHARED_LIB, libs, null, null);
			} catch (Error e) {
				debug (e.message);
				return null;
			}
		} else {
			res = pkbproxy.run_what_provides (filter, PackageKit.Provides.SHARED_LIB, libs);
			if (res == null) {
				debug ("Native backend PkResults was NULL!");
				return null;
			}
		}

		sack = res.get_package_sack ();
		if (sack == null)
			return null;
		string[] packages = sack.get_ids ();

		if ( (res.get_exit_code () != PackageKit.Exit.SUCCESS) || (packages[0] == null) ) {
			set_error (ErrorEnum.UNKNOWN, "%s\n%s".printf (_("Unable to find native package for '%s'!").printf (dep.full_name),
				_("PackageKit exit code was: %s").printf (PackageKit.exit_enum_to_string (res.get_exit_code ())))
			);
			return null;
		}

		return sack;
	}

	/* This method searches for dependency packages & stores them in dep.install_data */
	public bool search_dep_packages (ref IPK.Dependency dep) {
		bool ret = true;
		reset ();

		// If there are no files, consider this dependency as "installed"
		// This is usually an ERROR and might indicate a broken package
		if (!dep.has_components ()) {
			Report.log_error ("Dependency %s has no components assigned!".printf (dep.full_name));
			dep.satisfied = true;
			return true;
		}

		PackageKit.PackageSack? sack = pkit_pkgs_from_depfiles (dep);
		if (sack == null)
			return false;

		string[]? packages = sack.get_ids ();

		if (packages == null)
			ret = false;

		ret = false;
		for (uint i = 0; packages[i] != null; i++) {
			PackageKit.Package? pkg = sack.find_by_id (packages[i]);

			if (pkg == null) {
				ret = false;
				break;
			}
			// Skip packages which don't match the arch requirements
			/*var arch = pkg.get_arch ();
			debug ("Package architecture: %s", arch);
			if ((arch != "all") && (arch != Utils.system_machine ()))
				continue;
			*/

			debug ("Found native package: %s", pkg.get_id ());

			ret = true;
			if (pkg.get_info () == PackageKit.Info.INSTALLED)
				dep.add_installed_comp ("pkg:" + pkg.get_id ());
			else
				dep.add_installed_comp ("*pkg:" + pkg.get_id ());
		}
		if (!ret) {
			dep.clear_installdata ();
			return false;
		}

		/* Check if there are native packages which need to be installed.
		 * If not, the dependency is already satified. */
		dep.satisfied = true;
		foreach (string pkg in dep.get_installdata ()) {
			if (pkg.has_prefix ("*pkg:")) {
				dep.satisfied = false;
				break;
			}
		}

		return ret;
	}

	/**
	 * Get package-name (PK package-id) for filename
	 *
	 * @param fname The filename to search for
	 *
	 * @return Resolved package-id or NULL, if none was found
	 */
	public string? package_name_for_file (string fname) throws PkError {
		PackageKit.Bitfield filter = PackageKit.filter_bitfield_from_string ("installed;");

		PackageKit.Results? res = null;
		PackageKit.PackageSack? sack;

		if (pkbproxy == null) {
			try {
				res  = pktask.search_files (filter, {fname, null}, null, null);
			} catch (Error e) {
				debug (e.message);
				return null;
			}
		} else {
			debug ("::TODO");
			/*
			res = pkbproxy.run_search_files (filter, {fname, null});
			if (res == null) {
				debug ("Native backend PkResults was NULL!");
				return null;
			}
			*/
		}

		if (res == null)
			return null;

		sack = res.get_package_sack ();
		if (sack == null)
			return null;
		string[] packages = sack.get_ids ();

		if ( (res.get_exit_code () != PackageKit.Exit.SUCCESS)) {
			throw new PkError.TRANSACTION_FAILED (_("PackageKit transaction failed!\nExit message was: %s").printf (PackageKit.exit_enum_to_string (res.get_exit_code ())));
		}

		return packages[0];
	}

}

private class PkInstaller : PkListallerTask {

	public PkInstaller (Listaller.Config liconf) {
		base (liconf);
		set_error_hint_str ("PkInstaller");

		reset ();
	}

	private void pk_progress_cb (PackageKit.Progress progress, PackageKit.ProgressType type) {
		// TODO
	}

	private bool pkit_install_packages (string[] pkids) {
		PackageKit.Results? res = null;
		PackageKit.Error? pkerror = null;

		if (pkbproxy == null) {
			try {
				res = pktask.install_packages (PackageKit.TransactionFlag.NONE,
								pkids,
								null,
								pk_progress_cb);
			} catch (Error e) {
				set_error (ErrorEnum.DEPENDENCY_INSTALL_FAILED,
					_("Installation of native packages failed with message: %s").printf (e.message));
				return false;
			}
		} else {
			// If we need to use the native backend plugin proxy
			res = pkbproxy.run_install_packages (PackageKit.TransactionFlag.NONE, pkids);
			if (res == null) {
				debug ("Native backend PkResults was NULL!");
				return false;
			}
		}
		if (res == null)
			return false;

		pkerror = res.get_error_code ();
		if (pkerror != null) {
			set_error (ErrorEnum.DEPENDENCY_INSTALL_FAILED,
					_("Installation of native packages failed with message: %s").printf (pkerror.get_details ()));
			return false;
		}

		if ((res != null) && (res.get_exit_code () == PackageKit.Exit.SUCCESS))
			return true;

		warning ("An unknown error occurred while trying to install a native package!");
		/*emit_warning (_("Installation of native package '%s' failed!").printf (pkg.get_id ()) + "\n" +
				_("PackageKit exit code was: %s").printf (PackageKit.exit_enum_to_string (res.get_exit_code ())));*/

		return false;
	}

	/* This method install a dependency if necessary */
	public bool install_dependency (ref IPK.Dependency dep) {
		bool ret = true;
		// Just to be sure...
		if (last_error != null)
			return false;

		// return if dependency is already satified
		if (dep.satisfied)
			return true;

		/* Exit if we have no install-data: No package can be installed, dependency is not satisfied.
		 * (we might do a feed-install instead */
		if (!dep.has_installdata ())
			return false;

		/* We don't install dependencies via PK when unit tests are running.
		 * Consider everything as satisfied. (unittests can modify this, of course) */
		if (__unittestmode) {
			dep.satisfied = true;
			return true;
		}

		string[] pkgs = {};
		/* Now install every not-yet-installed package. The asterisk (*pkg) indicates
		 * that this package needs to be installed */
		foreach (string pkg in dep.get_installdata ()) {
			if (pkg.has_prefix ("*pkg:")) {
				pkgs += pkg.substring (5);
			}
		}
		// null-terminate the array
		pkgs += null;

		/* If no elements need to be installed and everything is already there,
		 * the dependency is satisfied and we can leave. */
		if (pkgs[0] == null) {
			dep.satisfied = true;
			return true;
		}

		// Now do the installing
		emit_message (_("Installing native packages: %s").printf (strv_to_string (pkgs)));
		ret = pkit_install_packages (pkgs);
		if (ret) {
			dep.satisfied = true;
			return true;
		}

		return false;
	}

}

} // End of namespace
