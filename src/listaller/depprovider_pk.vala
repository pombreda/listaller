/* depprovider_pk.vala
 *
 * Copyright (C) 2011  Matthias Klumpp
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author:
 * 	Matthias Klumpp <matthias@nlinux.org>
 */

using GLib;
using Gee;
using Listaller;

namespace Listaller.Deps {

private class PkitProvider : Provider {
	private PackageKit.Client pkit;

	public PkitProvider (IPK.Dependency ipkdep) {
		base (ipkdep);

		pkit = new PackageKit.Client ();
	}

	private void pk_progress_cb (PackageKit.Progress progress, PackageKit.ProgressType type) {
		// TODO
	}

	private PackageKit.Package? pkit_pkg_from_file (string fname) {
		PackageKit.Bitfield filter = PackageKit.Filter.bitfield_from_string ("none");
		string[] files = { fname, null };

		PackageKit.Results res = pkit.search_files (filter, files, null, pk_progress_cb);
		PackageKit.PackageSack sack = res.get_package_sack ();
		string[] packages = sack.get_ids ();

		if ( (res.get_exit_code () != PackageKit.Exit.SUCCESS) || (packages[0] == null) ) {
			debug (_("PackageKit exit code was: %s").printf (PackageKit.Exit.enum_to_string (res.get_exit_code ())));
			emit_warning (_("Unable to find native package for %s!").printf (dep.name));
			return null;
		}

		PackageKit.Package pkg = sack.find_by_id (packages[0]);

		return pkg;
	}

	private bool pkit_install_package (PackageKit.Package pkg) {
		string[] pkids = { pkg.get_id (), null };
		PackageKit.Results res = pkit.install_packages (true, pkids, null, pk_progress_cb);

		if (res.get_exit_code () == PackageKit.Exit.SUCCESS)
			return true;

		emit_warning (_("Installation of native package '%s' failed!").printf (pkg.get_id ()) + "\n" +
				_("PackageKit exit code was: %s").printf (PackageKit.Exit.enum_to_string (res.get_exit_code ())));
		return false;
	}

	public override bool execute () {
		bool ret = true;
		// PK solver can only handle files...
		foreach (string s in dep.files) {
			PackageKit.Package pkg = pkit_pkg_from_file (s);
			if (pkg == null) {
				ret = false;
				break;
			}
			if (pkg.get_info () != PackageKit.Info.INSTALLED) {
				emit_info (_("Installing native package %s").printf (pkg.get_id ()));
				ret = pkit_install_package (pkg);
				if (!ret)
					break;
			} else {
				emit_info (_("Native package %s is already installed.").printf (pkg.get_id ()));
			}
			if (ret)
				dep.meta_info.add ("pkg:" + pkg.get_id ());
		}
		if (!ret)
			dep.meta_info.clear ();
		return ret;
	}

}

} // End of namespace
