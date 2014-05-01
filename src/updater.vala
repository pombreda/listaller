/* updater.vala -- Update applications from IPK update repositories
 *
 * Copyright (C) 2012-2014 Matthias Klumpp <matthias@tenstral.net>
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
 * All necessary methods to keep installed applications up-to-date
 *
 * This class allows installing updates for installed applications.
 */
public class Updater : MessageObject {
	private SetupSettings ssettings;
	private Repo.Manager repo_mgr;
	private Manager app_mgr;

	public SetupSettings settings {
		get { return ssettings; }
		set { ssettings = value; }
	}

	public ArrayList<UpdateItem> available_updates { get; private set; }

	public signal void update (UpdateItem update);

	/**
	 * Create a new Listaller update manager
	 *
	 * @param shared_mode Whether we are in shared mode or not.
	 */
	public Updater (bool shared_mode = true) {
		base ();

		ssettings = new SetupSettings ();
		if (shared_mode)
			ssettings.current_mode = IPK.InstallMode.SHARED;
		else
			ssettings.current_mode = IPK.InstallMode.PRIVATE;

		available_updates = new ArrayList<UpdateItem> ();

		repo_mgr = new Repo.Manager ();
		connect_with_object (repo_mgr);

		app_mgr = new Manager (shared_mode);
		connect_with_object (app_mgr, ObjConnectFlags.IGNORE_PROGRESS);
	}

	private bool is_shared_mode () {
		return ssettings.current_mode == IPK.InstallMode.SHARED;
	}

	private void emit_update (Type sw_type, Object sw_old, Object sw_new, string arch, IPK.Changelog changes) {
		var item = new UpdateItem ();

		item.sw_type = sw_type;
		item.sw_old = sw_old;
		item.sw_new = sw_new;
		item.architecture = arch;
		item.changelog = changes;

		available_updates.add (item);

		update (item);
	}

	private void emit_update_app (AppItem app_old, AppItem app_new, string arch, IPK.Changelog changes) {
		emit_update (app_old.get_type (), app_old, app_new, arch, changes);
	}

	/**
	 * Find updates available for installed applications.
	 */
	public void find_updates () {
		// fetch all installed applications
		ArrayList<AppItem> apps_installed;
		AppState filter = AppState.INSTALLED_SHARED | AppState.INSTALLED_PRIVATE;
		app_mgr.filter_applications (filter, out apps_installed);

		if (apps_installed == null) {
			critical ("Unable to fetch installed applications!");
			return;
		}

		// fetch all available applications
		HashMap<string, AppItem> apps_available = repo_mgr.get_applications ();

		// clear list of available updates (will automatically be refilled)
		available_updates.clear ();

		foreach (AppItem app_i in apps_installed) {
			AppItem? app_remote = null;
			app_remote = apps_available.get (app_i.idname);
			if (app_remote == null) {
				debug ("No remote app for '%s' found.", app_i.idname);
				continue;
			}

			// check if remote version is newer
			if (compare_versions (app_i.version, app_remote.version) < 0) {
				var changes = new IPK.Changelog ();
				// TODO: set valid changelog data
				string arch = repo_mgr.get_arch_for_app (app_i);
				emit_update_app (app_i, app_remote, arch, changes);
			}
		}
	}

	private bool perform_application_update (AppItem app_old, AppItem app_new, string arch) {
		bool ret;
		Setup? inst = repo_mgr.get_setup_for_remote_app (app_new, arch);
		if (inst == null) {
			emit_error (ErrorEnum.UPDATE_FAILED,
				_("Update of application '%s' failed. Maybe the update information is out of date. Please refresh it and try again.").printf (app_old.info.name));
			return false;
		}

		connect_with_object (inst);
		ret = inst.initialize ();
		if (!ret)
			return false;

		// set correct installation mode
		IPK.InstallMode imode = IPK.InstallMode.SHARED;
		if (app_old.state == AppState.INSTALLED_PRIVATE)
			imode = IPK.InstallMode.PRIVATE;
		inst.settings.current_mode = imode;
		inst.set_install_mode (imode);

		SecurityLevel minSecLvl;
		SecurityLevel packSecLvl;
		if (!inst.installation_allowed (out minSecLvl, out packSecLvl)) {
			// we are not allowed to update this package!
			string message = _("You are not allowed to update the application '%s'! The security level of the update is '%s' and you need at least security-level '%s'.\n" +
				"Please make sure you trusted this signature and that your system is not compromised!").printf (app_old.idname, packSecLvl.to_string (), minSecLvl.to_string ());
			if (Utils.__unittestmode) {
				debug (message);
			} else {
				emit_error (ErrorEnum.OPERATION_NOT_ALLOWED, message);
				return false;
			}
		}

		// remove old application so we can install the update
		ret = app_mgr.remove_application (app_old);
		if (!ret) {
			emit_error (ErrorEnum.UPDATE_FAILED,
				_("Update of application '%s' failed. Unable to remove the old application.").printf (app_old.info.name));
			return false;
		}

		// old app should be gone now, so we install the fresh version
		ret = inst.run_installation ();
		if (!ret) {
			// FIXME: a better error message would be awesome ;-)
			emit_error (ErrorEnum.UPDATE_FAILED,
				_("Update of application '%s' failed. Something bad happened. Please install the application again!").printf (app_old.info.name));
			return false;
		}

		return true;
	}

	/**
	 * Apply updates selected in update_list.
	 *
	 * @param update_list A list containing valid UpdateItems
	 */
	public bool apply_updates (ArrayList<UpdateItem> update_list) {
		if (update_list.size == 0)
			return true;
		bool ret;

		foreach (UpdateItem item in update_list) {
			if (item.completed)
				continue;

			if (item.sw_type == typeof (AppItem)) {
				ret = perform_application_update (item.sw_old as AppItem,
							    item.sw_new as AppItem,
							    item.architecture);
				if (!ret)
					return false;
				else
					item.completed = true;

			} else if (item.sw_type == typeof (Dependency)) {
				// TODO
			} else {
				warning ("Found UpdateItem with invalid software type: %s", item.sw_type.name ());
			}
		}

		return true;
	}

	/**
	 * Apply all available updates
	 */
	public bool apply_updates_all () {
		return apply_updates (available_updates);
	}

}

} // End of namespace: Listaller
