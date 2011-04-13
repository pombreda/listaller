/* scan_ldd.vala
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

private class DepscanLDD : Object, IDepScanEngine {
	private ArrayList<string> filedeps;

	public DepscanLDD () {
		filedeps = new ArrayList<string> ();
	}

	public bool fetch_required_files (string binaryname) {
		filedeps.clear ();

		string cmd = "/usr/bin/ldd " + binaryname;
		string output, stderror = null;
		int exit_status = 0;
		try {
			Process.spawn_command_line_sync (cmd, out output, out stderror, out exit_status);
		} catch (SpawnError e) {
			debug (e.message);
			return false;
		}
		if ((exit_status != 0) || (output == null))
			return false;
		string[] tmp = output.split ("\n");

		for (int i = 0; i < tmp.length; i++) {
			string h = tmp[i];
			string[] dep = h.split ("=>");
			if (dep.length <= 0)
				continue;
			h = dep[0].strip ();
			if (!h.contains ("("))
				filedeps.add (h);
		}
		return true;
	}

	public bool can_be_used (string fname) {
		return FileUtils.test (fname, FileTest.IS_EXECUTABLE);
	}

	public ArrayList<string> required_files () {
		return filedeps;
	}
}
