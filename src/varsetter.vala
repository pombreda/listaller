/* varsetter.vala
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
using Listaller;

namespace Listaller {

private class VarSetter : Object {
	private Listaller.Settings conf;
	private VarSolver vs;

	public VarSetter (Listaller.Settings liconfig, string appIdName) {
		conf = liconfig;
		vs = new VarSolver (appIdName);
	}

	private string get_desktopfile_entry (KeyFile dfile, string keyword) {
		string value;
		try {
			if (dfile.has_key ("Desktop Entry", keyword)) {
				value = dfile.get_string ("Desktop Entry", keyword);
			} else {
				value = "";
			}
		} catch (Error e) {
			warning (_("Could not load desktop file values: %s").printf (e.message));
			return "";
		}
		return value;
	}

	private void process_desktopfile (string fname) {
		KeyFile dfile = new KeyFile ();
		try {
			dfile.load_from_file (fname, KeyFileFlags.NONE);
		} catch (Error e) {
			error (_("Could not open desktop file: %s").printf (e.message));
		}
		string value;

		value = get_desktopfile_entry (dfile, "Icon");
		if (value != "")
			dfile.set_string ("Desktop Entry", "Icon", vs.substitute_vars_auto (value, conf));

		value = get_desktopfile_entry (dfile, "Exec");
		// Process exe filename and append the runapp command
		if (value != "")
			dfile.set_string ("Desktop Entry", "Exec", "runapp \"" + vs.substitute_vars_auto (value, conf) + "\"");

		// Now save the modified file
		FileUtils.remove (fname);
		try {
			var file = File.new_for_path (fname);
			{
				var file_stream = file.create (FileCreateFlags.NONE);

				if (!file.query_exists ()) {
					warning (_("Unable to save modified desktop-file!"));
					return;
				}

				var data_stream = new DataOutputStream (file_stream);
				data_stream.put_string (dfile.to_data ());
			}
		} catch (Error e) {
			error (_("Unable to save modified desktop-file! Message: %s").printf (e.message));
			return;
		}
	}

	public void execute (string fname) {
		if (!FileUtils.test (fname, FileTest.IS_REGULAR))
			return;
		if (fname.has_suffix (".desktop"))
			process_desktopfile (fname);
		return;
	}
}

} // End of namespace