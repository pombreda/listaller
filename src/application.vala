/* application.vala
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

namespace Listaller {

public enum AppOrigin {
	IPK,
	NATIVE,
	UNKNOWN,
	INVALID;

	public string to_string() {
		switch (this) {
			case IPK:
				return ("package_ipk");

			case NATIVE:
				return ("package_native");

			case UNKNOWN:
				return ("unknown");

			default:
				return ("<fatal:origin-not-found>");
		}
	}
}

public class AppItem : Object {
	private string _idname;
	private string _version;
	private string _appname;
	private string _summary;
	private string _author;
	private string _archs;
	private string _pkgmaintainer;
	private string _categories;
	private string _desktop_file;
	private string _desktop_file_prefix;
	private string _url;
	private string _icon_name;
	private int64  _install_time;
	private string _dependencies;
	private AppOrigin _origin;
	private int _dbid;
	private string _app_id;
	private Listaller.Settings? _liconf;

	public string idname {
		get {
			if (_idname.strip () == "")
				_idname = string_replace (_appname.down (), "( )", "_");
			return _idname;
		}
		set {
			_idname = value;
			if (_appname.strip () == "")
				_appname = _idname;
		}
	}

	public string full_name {
		get { return _appname; }
		set { _appname = value; }
	}

	public string version {
		get { return _version; }
		set { _version = value; }
	}

	public string summary {
		get { return _summary; }
		set { _summary = value; }
	}

	public string author {
		get { return _author; }
		set { _author = value; }
	}

	public string maintainer {
		get { return _pkgmaintainer; }
		set { _pkgmaintainer = value; }
	}

	public string categories {
		get { return _categories; }
		set { _categories = value; }
	}

	public string desktop_file {
		get {
			if (_desktop_file.strip () == "")
				return "";
			string dfile = _desktop_file;
			if ((!dfile.has_prefix ("$")) && (!dfile.has_prefix ("/"))) {
				// If no exact path has been specified, we assume $APP
				dfile = Path.build_filename ("$APP", dfile, null);
			}
			_desktop_file_prefix = dfile;
			return _desktop_file_prefix;
		}
		set { _desktop_file = value; }
	}

	public string icon_name {
		get { return _icon_name; }
		set { _icon_name = value; }
	}

	public string url {
		get { return _url; }
		set { _url = value; }
	}

	public int64 install_time {
		get { return _install_time; }
		set { _install_time = value; }
	}

	public AppOrigin origin {
		get { return _origin; }
		set { _origin = value; }
	}

	public string dependencies {
		get { return _dependencies; }
		set { _dependencies = value; }
	}

	public string archs {
		get { return _archs; }
		set { _archs = value; }
	}

	public string appid {
		get { _app_id = generate_appid (); return _app_id; }
	}

	public Listaller.Settings lisettings {
		set { _liconf = value; }
	}

	/*
	 * Id the application has in the database
	 */
	public int dbid {
		get { return _dbid; }
		set { _dbid = value; }
	}

	public AppItem.blank () {
		_idname = "";
		_appname = "";
		_idname = "";
		_summary = "";
		install_time = 0;
		categories = "all;";
		dbid = -1;
		origin = AppOrigin.UNKNOWN;
		_app_id = "";
		_desktop_file = "";
		_url = "";
		_icon_name = "";
		archs = system_architecture ();
		_liconf = null;
	}

	public AppItem (string afullname, string aversion, string aarchs = "") {
		this.blank ();
		full_name = afullname;
		version = aversion;
		if (aarchs != "")
			archs = aarchs;
	}

	public AppItem.from_id (string application_id) {
		this.blank ();
		_app_id = application_id;
		update_with_appid ();
	}

	public AppItem.from_desktopfile (string desktop_filename) {
		this.blank ();
		desktop_file = desktop_filename;
		this.update_with_desktop_file ();
	}

	public string to_string () {
		return "[ (" + idname + ") "
			+ "(" + version +") "
			+ "! " + appid + " ::" + dbid.to_string () + " "
			+ "]";
	}

	protected Listaller.Settings liconfig () {
		if (_liconf == null) {
			return new Listaller.Settings ();
		}
		return _liconf;
	}

	public void fast_check () {
		// Fast sanity checks for AppItem
		assert (idname != null);
		assert (full_name != null);
		assert (version != null);
		assert (appid != "");
	}

	public void set_origin_from_string (string s) {
		switch (s) {
			case ("package_ipk"):
				origin = AppOrigin.IPK;
				break;

			case ("package_native"):
				origin = AppOrigin.NATIVE;
				break;

			case ("unknown"):
				origin = AppOrigin.UNKNOWN;
				break;

			default:
				origin = AppOrigin.INVALID;
				break;
		}
	}

	private string generate_appid () {
		string res = "";
		if (validate_appid (_app_id))
			return _app_id;
		// Build a Listaller application-id
		/* An application ID has the following form:
		 * idname;version;archs;app_dir~origin
		 * idname usually is the application's .desktop file name
		 * version is the application's version
		 * arch the architecture(s) the app was build for
		 * app_dir the application meta info dir, e.g. $APP or local/applications
		 * origin is the origin of this app, ipkpackage, native-pkg, LOKI etc.
		 */
		if (desktop_file.strip () == "") {
			message (_("We don't know a desktop-file for application '%s'!").printf (full_name));
			// If no desktop file was found, use application name and version as ID
			res = idname + ";" + version;
			res = res.down ();
			res = res + ";" + archs + ";~" + origin.to_string ();
		} else {
			res = idname + ";" + version + ";" + archs + ";";
			res += desktop_file;
			res += "~" + origin.to_string ();
		}
		return res;
	}

	public static bool validate_appid (string application_id) {
		string inv_str = _("Application ID %s is invalid!").printf (application_id);
		// Check if application-id is valid
		if (application_id == "")
			return false;
		if (count_str (application_id, ";") != 3) {
			warning (inv_str);
			return false;
		}
		if (count_str (application_id, "~") != 1) {
			warning (inv_str);
			return false;
		}
		string[] blocks = application_id.split (";");
		if ((blocks[0] == null) || (blocks[1] == null)) {
			warning (inv_str);
			return false;
		}
		return true;
	}

	public void update_with_appid (bool fast = false) {
		if (!validate_appid (appid))
			return;

		string[] blocks = appid.split (";");
		idname = blocks[0];
		version = blocks[1];
		archs = blocks[2];

		// Set application origin
		string orig_block = blocks[3];
		string[] orig = orig_block.split ("~");
		string? dfile = orig[0];
		set_origin_from_string (orig[1]);

		// Rebuild the desktop file
		if (dfile != null) {
			desktop_file = dfile;
			if (!fast)
				update_with_desktop_file ();
		}

	}

	private string get_desktop_file_string (KeyFile dfile, string keyword) {
		try {
			if (dfile.has_key ("Desktop Entry", keyword)) {
				return dfile.get_string ("Desktop Entry", keyword);
			} else {
				return "";
			}
		} catch (Error e) {
			error (_("Could not load desktop file values: %s").printf (e.message));
		}
	}

	public void update_with_desktop_file () {
		if (desktop_file == "")
			return;
		// Resolve variables in desktop_file path
		string fname;
		// Set idname if no idname was specified
		if (idname == "") {
			idname = string_replace (Path.get_basename (desktop_file), "(.desktop)", "");
			debug ("Set app-idname from desktop filename: %s".printf (idname));
		}
		/* NOTE: Hopefully nobody will ever try to store a .desktop-file in $INST, because
		 * this might cause problems with AppItem's which don't have the correct idname specified.
		 * (Maybe limit this to $APP only?)
		 */
		VarSolver vs = new VarSolver (idname);
		fname = vs.substitute_vars_auto (desktop_file, liconfig ());

		// Check if file exists
		if (!FileUtils.test (fname, FileTest.EXISTS))
			return;
		// Load new values from desktop file
		KeyFile dfile = new KeyFile ();
		try {
			dfile.load_from_file (fname, KeyFileFlags.NONE);
		} catch (Error e) {
			error (_("Could not open desktop file: %s").printf (e.message));
		}

		full_name = get_desktop_file_string (dfile, "Name");
		if (idname == "")
			idname = full_name;
		version = get_desktop_file_string (dfile, "X-AppVersion");
		summary = get_desktop_file_string (dfile, "Comment");
		icon_name = get_desktop_file_string (dfile, "Icon");
		author = get_desktop_file_string (dfile, "X-Author");
		categories = get_desktop_file_string (dfile, "Categories");
		maintainer = get_desktop_file_string (dfile, "X-Packager");
	}

}

} // End of namespace
