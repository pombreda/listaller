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
		conf = settings;
		if (conf == null)
			conf = new Settings (false);
		fname = ipkfilename;
		// Set up IPK package instance
		ipkp = new IPK.Package (fname, settings);
		ipkp.error_code.connect ((e) => { this.error_code (e); });
		ipkp.message.connect ((m) => { this.message (m); });
		ipkp.progress_changed.connect (receive_progress_change);
		initialized = false;
	}

	private void receive_progress_change (int progress, int subprogress) {
		progress_changed (progress, subprogress);
	}

	private void emit_warning (string msg) {
		// Construct warning message
		MessageItem item = new MessageItem(MessageEnum.WARNING);
		item.details = msg;
		message (item);
		warning (msg);
	}

	private void emit_message (string msg) {
		// Construct info message
		MessageItem item = new MessageItem(MessageEnum.INFO);
		item.details = msg;
		message (item);
		GLib.message (msg);
	}

	private void emit_error (ErrorEnum id, string details) {
		// Construct error
		ErrorItem item = new ErrorItem(id);
		item.details = details;
		error_code (item);
		critical (details);
	}

	public bool initialize () {
		bool ret = false;
		ret = ipkp.initialize ();
		if (ret)
			initialized = true;
		return ret;
	}

	public bool run_installation () {
		// Check if setup was initialized
		if (!initialized) {
			emit_error (ErrorEnum.SETUP_NOT_INITIALIZED, _("Setup has not been initialized!"));
			return false;
		}
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
		db.open ();

		// Construct LiAppItem
		AppItem aitem = new AppItem (ipkp.control.get_app_name (), ipkp.control.get_app_version ());
		aitem.origin = AppOrigin.IPK;
		aitem.summary = ipkp.control.get_app_summary ();
		//aitem.author = ipkp.control.get_app_author ();
		//aitem.pkgmaintainer = ipkp.control.get_pkg_maintainer ();
		//aitem.categories = ipkp.control.get_app_categories ();
		//aitem.desktop_file = ipkp.control.get_app_desktopfile ();
		aitem.dependencies = "?";
		aitem.fast_check ();

		// Emit status message
		StatusItem status1 = new StatusItem (StatusEnum.RESOLVING_DEPENDENCIES);
		status1.info = _("Resolving dependencies of '%s'.").printf (ipkp.control.get_app_name ());
		status_changed (status1);

		// TODO: Resolve dependencies here!

		// Emit status message
		StatusItem status2 = new StatusItem (StatusEnum.INSTALLING_FILES);
		status2.info = _("Copying files to their destination");
		status_changed (status2);

		// Install all files to their destination
		ret = ipkp.install_all_files ();

		if (!ret)
			return false;

		// Emit status message
		StatusItem status3 = new StatusItem (StatusEnum.REGISTERING_APPLICATION);
		status3.info = _("Making '%s' known to your system.").printf (ipkp.control.get_app_name ());
		status_changed (status3);

		// Set install timestamp
		DateTime dt = new DateTime.now_local ();
		aitem.install_time = dt.to_unix ();
		// Now register the item
		ret = db.add_application (aitem);
		conf.unlock ();

		return ret;
	}
}

} // End of namespace
