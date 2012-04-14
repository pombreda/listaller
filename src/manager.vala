/* manager.vala - Manage installed applications (remove them / maintain their dependencies)
 *
 * Copyright (C) 2010-2012 Matthias Klumpp <matthias@tenstral.net>
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

[CCode (cheader_filename = "listaller-glib/manager.h")]

namespace Listaller {

/**
 * Allows managing installed applications
 *
 * This class allows managing installed applications as
 * well as performing maintainance tasks to keep applications
 * running.
 */
public class Manager : MsgObject {
	private Settings conf;

	public signal void status_changed (StatusItem status);
	public signal void application (AppItem appid);

	public Settings settings {
		get { return conf; }
		set { conf = value; }
	}

	/*
	 * @param: settings A valid LiSettings instance, describing basic settings (or null)
	 */
	public Manager (Settings? settings) {
		base ();
		conf = settings;
		if (conf == null)
			conf = new Settings (false);
	}

	private void emit_status (StatusEnum status, string info) {
		StatusItem item = new StatusItem (status);
		item.info = info;
		status_changed (item);
	}

	private bool init_db (out SoftwareDB sdb, bool writeable = true) {
		SoftwareDB db = new SoftwareDB (conf, true);
		// Connect the database events with this application manager
		connect_with_object (db, ObjConnectFlags.NONE);
		db.application.connect ( (a) => { this.application (a); } );

		sdb = db;
		if (writeable) {
			if (!db.open_write ()) {
				emit_error (ErrorEnum.DB_OPEN_FAILED, _("Unable to open software database for reading & writing!"));
				return false;
			}
		} else {
			if (!db.open_read ()) {
				emit_error (ErrorEnum.DB_OPEN_FAILED, _("Unable to open software database for reading only!"));
				return false;
			}
		}
		return true;
	}

	public bool find_applications (AppSource filter, out ArrayList<AppItem> appList = null) {
		SoftwareDB db;
		if (!init_db (out db, false))
			return false;

		return db.find_all_applications (filter, out appList);
	}

	/* find_applications_by_values: Find applications which match the strings in values
	 *
	 * @values:
	 */
	public bool find_applications_by_values (AppSource filter,
						 [CCode (array_null_terminated = true, array_length = false)] string[] values,
						 out ArrayList<AppItem> appList = null) {
		SoftwareDB db;
		if (!init_db (out db, false))
			return false;

		ArrayList<AppItem> res = db.find_applications (values);
		// Emit signals for found applications
		foreach (AppItem app in res)
			application (app);
		return true;
	}

	private bool remove_application_internal (AppItem app) {
		// Emit that we're starting
		emit_status (StatusEnum.ACTION_STARTED,
			     _("Removal of %s started.").printf (app.full_name));

		SoftwareDB db;
		if (!init_db (out db))
			return false;

		// Check if this application exists, if not exit
		if (db.get_application_by_id (app) == null) {
			emit_error (ErrorEnum.REMOVAL_FAILED, _("Could not uninstall application %s. It is not installed.").printf (app.full_name));
			return false;
		}
		// Remove all files which belong to this application
		ArrayList<string>? files = db.get_application_filelist (app);
		if (files == null) {
			emit_error (ErrorEnum.REMOVAL_FAILED, _("'%s' has no file-list registered. The software database might be broken.").printf (app.full_name));
			return false;
		}

		foreach (string fname in files) {
			if (FileUtils.test (fname, FileTest.EXISTS)) {
				int ret = FileUtils.remove (fname);
				if (ret != 0) {
					emit_error (ErrorEnum.REMOVAL_FAILED, _("Could not remove file %s!").printf (fname));
					return false;
				}
				string dirn = Path.get_dirname (fname);
				// Remove directory if it is empty
				if (dir_is_empty (dirn)) {
					DirUtils.remove (dirn);
				}
			}
		}
		bool ret = db.remove_application (app);

		emit_status (StatusEnum.REMOVAL_FINISHED,
			     _("Removal of %s finished.").printf (app.full_name));

		return ret;
	}

	private void pk_progress_cb (PackageKit.Progress progress, PackageKit.ProgressType type) {
		if ((type == PackageKit.ProgressType.PERCENTAGE) ||
			(type == PackageKit.ProgressType.SUBPERCENTAGE)) {
				change_progress (progress.percentage, progress.subpercentage);
			}
	}

	private bool remove_shared_application_internal (AppItem app) {
		bool ret = true;
		PackageKit.Task pktask = new PackageKit.Task ();

		/* PackageKit will handle all Listaller superuser uninstallations.
		 * Therefore, PackageKit needs to be compiled with Listaller support enabled.
		 */

		PackageKit.Results? pkres;
		pktask.background = false;

		string pklipackage = app_item_build_pk_package_id (app);
		change_progress (0, -1);

		try {
			pkres = pktask.remove_packages ({ pklipackage, null }, false, true, null, pk_progress_cb);
		} catch (Error e) {
			emit_error (ErrorEnum.REMOVAL_FAILED, e.message);
			return false;
		}

		if (pkres.get_exit_code () != PackageKit.Exit.SUCCESS) {
			PackageKit.Error error = pkres.get_error_code ();
			emit_error (ErrorEnum.REMOVAL_FAILED, error.get_details ());
			return false;
		}

		change_progress (100, -1);

		// Emit status message (setup finished)
		emit_status (StatusEnum.REMOVAL_FINISHED,
			     _("Removal of %s finished.").printf (app.full_name));

		return ret;

	}

	public bool remove_application (AppItem app) {
		app.fast_check ();

		bool sumode_old = conf.sumode;
		if (app.shared != conf.sumode) {
			if (app.shared)
				debug (_("Trying to remove shared application, but AppManager is not in superuser mode!\nSetting AppManager to superuse mode now."));
			else
				debug (_("Trying to remove local application, but AppManager is in superuser mode!\nSetting AppManager to local mode now."));
			conf.sumode = app.shared;
		}

		bool ret;
		if ((app.shared) && (!is_root ())) {
			// Call PackageKit if we aren't root and want to remove a shared application
			ret = remove_shared_application_internal (app);
		} else {
			// Try normal app removal
			ret = remove_application_internal (app);
		}

		conf.sumode = sumode_old;

		return ret;
	}

	public AppItem? get_appitem_by_idname (string idname) {
		SoftwareDB db;
		if (!init_db (out db, false))
			return null;

		AppItem? app = db.get_application_by_idname (idname);
		return app;
	}

	public bool refresh_appitem (ref AppItem item) {
		SoftwareDB db;
		if (!init_db (out db, false))
			return false;

		// We only want to fetch dependencies from the correct database, so limit DB usage
		if (item.shared)
			db.force_db = ForceDB.SHARED;
		else
			db.force_db = ForceDB.PRIVATE;

		var tmpItem = db.get_application_by_idname (item.idname);
		if (tmpItem == null)
			return false;
		item = tmpItem;

		return true;
	}

	public string? get_application_filelist_as_string (AppItem app) {
		app.fast_check ();

		SoftwareDB db;
		if (!init_db (out db))
			return null;

		// Check if this application exists, if not exit
		if (db.get_application_by_id (app) == null) {
			warning ("Unable to get file-list for application %s - app is not installed!", app.idname);
			return null;
		}

		// Remove all files which belong to this application
		ArrayList<string>? files = db.get_application_filelist (app);
		if (files == null) {
			critical ("Couldn't retrieve file-list for application %s! All apps should have a filelist, this should never happen!", app.idname);
			return null;
		}

		string res = "";
		foreach (string s in files)
			res += "%s\n".printf (s);

		return res;
	}

	public string get_app_ld_environment (AppItem app) {
		if (app.dbid < 0) {
			debug ("AppItem database id was < 0! Application was maybe not retrieved from software DB and therefore lacks the required data.");
			debug ("Setting empty environment...");
			return "";
		}

		SoftwareDB db;
		if (!init_db (out db, false)) {
			debug ("Unable to open DB, app environment will be empty!");
			return "";
		}

		// We only want to fetch dependencies from the correct database, so limit DB usage
		if (app.shared)
			db.force_db = ForceDB.SHARED;
		else
			db.force_db = ForceDB.PRIVATE;

		// A new DepManager for the resolving...
		DepManager depman = new DepManager (db);

		string[] depStr = app.dependencies.split ("\n");

		string paths = "";

		HashSet<IPK.Dependency> depList = depman.dependencies_from_idlist (depStr);

		foreach (IPK.Dependency dep in depList) {
			// Now get paths for library, if possible (if dependency is a library)
			string p = depman.get_absolute_library_path (dep);
			if (p != "")
				paths = "%s;%s".printf (paths, p);
		}

		return paths;
	}

	public AppItem? get_appitem_by_fullname (string full_name) {
		SoftwareDB db;
		if (!init_db (out db, false))
			return null;

		AppItem? app = db.get_application_by_fullname (full_name);
		return app;
	}

	public bool scan_applications () {
		//TODO: Scan for 3rd-party installed apps
		return true;
	}

}

} // End of namespace
