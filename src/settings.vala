/* settings.vala
 *
 * Copyright (C) 2009-2011  Matthias Klumpp
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

using PkgConfig;
using GLib;

// Workaround for Vala bug #618931
private const string _PKG_VERSION1 = PkgConfig.VERSION;

private bool LI_TESTMODE = false;

private class LiSettings : Object {
	private bool sumode;
	const string suconfdir = "/etc/lipa";

	public bool superuserMode {
		get { return sumode; }
		set { sumode = value; }
	}

	public LiSettings (bool root = false) {
		sumode = root;
	}

	public string database_file () {
		return appregister_dir () + "/software.db";
	}

	public string appregister_dir () {
		string regdir;
		if (sumode) {
			regdir = suconfdir;
		} else {
			regdir = Environment.get_user_config_dir () + "/software";
		}

		File d = File.new_for_path (regdir);
		try {
			if (!d.query_exists ()) {
				d.make_directory_with_parents ();
			}
		} catch (Error e) {
			stderr.printf (_("Unable to create application database directory: %s\n").printf (e.message));
		}

		return regdir;
	}

	public string tmp_dir () {
		string ret;
		ret = Environment.get_tmp_dir ();
		return ret;
	}

	public string get_unique_tmp_dir () {
		string template = Path.build_filename (tmp_dir (), "listaller-XXXXXX", null);

		string res = DirUtils.mkdtemp (template);
		if (res == null)
			res = tmp_dir ();
		return res;
	}

	public bool is_testmode () {
		return LI_TESTMODE;
	}
}

public void li_enable_translation ()
{
	// Initialize localisation
	Intl.bindtextdomain (PkgConfig.GETTEXT_PACKAGE, PkgConfig.LOCALEDIR);
	Intl.bind_textdomain_codeset (PkgConfig.GETTEXT_PACKAGE, "UTF-8");
	Intl.textdomain (PkgConfig.GETTEXT_PACKAGE);
}
