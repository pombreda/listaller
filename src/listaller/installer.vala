/* installer.vala
 *
 * Copyright (C) 2010-2011  Matthias Klumpp
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
using Listaller;

[CCode (cheader_filename = "listaller-glib/installer.h")]

namespace Listaller {

public class Setup : Object {
	private Settings conf;
	private string fname;
	private IPK.Package ipkp;
	private bool initialized;
	private int inst_progress;
	private int full_progress;
	public bool unittestmode {get; set;}

	public signal void error_code (ErrorItem error);
	public signal void progress_changed (int progress, int subprogress);
	public signal void status_changed (StatusItem status);
	public signal void message (MessageItem message);

	public Settings settings {
		get { return conf; }
	}

	public IPK.Control? control {
		get { if (initialized) {
				return ipkp.control;
			} else {
				return null;
			}
		}
	}

	public Setup (string ipkfilename, Settings? settings) {
		unittestmode = false;
		conf = settings;
		if (conf == null)
			conf = new Settings (false);
		fname = ipkfilename;
		// Set up IPK package instance
		ipkp = new IPK.Package (fname, settings);
		ipkp.error_code.connect ((e) => { this.error_code (e); });
		ipkp.message.connect ((m) => { this.message (m); });
		ipkp.progress_changed.connect ((i) => { change_progress (i, -1); });
		initialized = false;
	}

	private void change_progress (int progress, int subprogress) {
		if (progress >= 0)
			full_progress = (int) Math.round ((inst_progress + progress) / 2);
		progress_changed (full_progress, subprogress);
	}

	private void emit_message (string msg) {
		// Construct info message
		MessageItem item = new MessageItem(MessageEnum.INFO);
		item.details = msg;
		message (item);
	}

	private void emit_warning (string msg) {
		// Construct warning message
		MessageItem item = new MessageItem(MessageEnum.WARNING);
		item.details = msg;
		message (item);
		stdout.printf ("WARNING: %s\n", msg);
	}

	private void emit_error (ErrorEnum id, string details) {
		// Construct error
		ErrorItem item = new ErrorItem(id);
		item.details = details;
		error_code (item);
		stdout.printf ("ERROR: %s\n", details);
	}

	public bool initialize () {
		bool ret = false;
		ret = ipkp.initialize ();
		if (ret)
			initialized = true;
		inst_progress = 0;
		full_progress = 0;
		return ret;
	}

	private bool install_application () {
		bool ret = true;

		conf.lock ();
		// Create software DB link and connect status handlers
		SoftwareDB db = new SoftwareDB (conf);
		db.error_code.connect ((error) => {
			this.error_code (error);
		});
		db.message.connect ((message) => {
			this.message (message);
		});
		// Open & lock database
		if (!db.open ()) {
			emit_error (ErrorEnum.DB_OPEN_FAILED, _("Could not open the software database, maybe it is locked at time.\nPlease close all other running installations to continue!"));
			return false;
		}

		// Construct LiAppItem
		AppItem app = ipkp.control.get_application ();
		app.origin = AppOrigin.IPK;
		app.dependencies = "?";
		app.fast_check ();

		inst_progress = 25;
		change_progress (0, -1);

		// Check if this application is already installed
		if (db.get_application_by_id (app) != null) {
			db.close ();
			emit_error (ErrorEnum.ALREADY_INSTALLED, _("This application was already installed. Please remove the existing version to continue!"));
			return false;
		}

		// Emit status message
		StatusItem status1 = new StatusItem (StatusEnum.RESOLVING_DEPENDENCIES);
		status1.info = _("Resolving dependencies of '%s'.").printf (app.full_name);
		status_changed (status1);

		// We don't solve dependencies when unit tests are running
		if (!unittestmode) {
			Deps.Solver solver = new Deps.Solver (ipkp.control.get_pkg_dependencies (), db);
			solver.error_code.connect ((error) => {
				this.error_code (error);
			});
			solver.message.connect ((msg) => {
				this.message (msg);
			});
			solver.progress_changed.connect ((p) => {
				change_progress (-1, p);
			});

			ret = solver.execute ();
			if (!ret) {
				db.close ();
				return false;
			}
		}

		inst_progress = 50;

		// Emit status message
		StatusItem status2 = new StatusItem (StatusEnum.INSTALLING_FILES);
		status2.info = _("Copying files to their destination");
		status_changed (status2);

		// Install all files to their destination
		ret = ipkp.install_all_files ();

		if (!ret) {
			db.close ();
			return false;
		}

		inst_progress = 75;
		change_progress (100, -1);

		// Emit status message
		StatusItem status3 = new StatusItem (StatusEnum.REGISTERING_APPLICATION);
		status3.info = _("Making '%s' known to your system.").printf (app.full_name);
		status_changed (status3);

		// Set install timestamp
		DateTime dt = new DateTime.now_local ();
		app.install_time = dt.to_unix ();
		// Now register the item
		ret = db.add_application (app);
		if (!ret) {
			db.close ();
			return false;
		}
		ret = db.add_application_filelist (app, ipkp.file_list);
		db.close ();

		conf.unlock ();

		inst_progress = 100;
		change_progress (100, -1);

		// Emit status message (setup finished)
		StatusItem status4 = new StatusItem (StatusEnum.INSTALLATION_FINISHED);
		if (ret) {
			status4.info = _("Installation completed!");
		} else {
			// Undo all changes
			ipkp.rollback_installation ();
			status4.info = _("Installation failed!");
		}
		status_changed (status4);

		return ret;
	}

	private void pk_progress_cb (PackageKit.Progress progress, PackageKit.ProgressType type) {
		if ((type == PackageKit.ProgressType.PERCENTAGE) ||
			(type == PackageKit.ProgressType.SUBPERCENTAGE)) {
				change_progress (progress.percentage, progress.subpercentage);
			}
	}

	private bool install_superuser () {
		PackageKit.Client client = new PackageKit.Client ();

		/* PackageKit will handle all Listaller superuser installations.
		 * Therefore, PackageKit needs to be compiled with Listaller support enabled.
		 */

		PackageKit.Results? pkres;
		client.background = false;

		try {
			pkres = client.install_files (true, { fname, null }, null, pk_progress_cb);
		} catch (Error e) {
			emit_error (ErrorEnum.INSTALLATION_FAILED, e.message);
			return false;
		}

		if (pkres.get_exit_code () != PackageKit.Exit.SUCCESS) {
			PackageKit.Error error = pkres.get_error_code ();
			emit_error (ErrorEnum.INSTALLATION_FAILED, error.get_details ());
			return false;
		}

		return true;
	}

	public bool run_installation () {
		bool ret = false;

		// Check if setup was initialized
		if (!initialized) {
			emit_error (ErrorEnum.SETUP_NOT_INITIALIZED, _("Setup has not been initialized!"));
			return false;
		}

		if ((!is_root ()) && (conf.sumode == true)) {
			ret = install_superuser ();
			return ret;
		}

		ret = install_application ();
		return ret;
	}
}

} // End of namespace
