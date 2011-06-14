/* prepare.vala
 *
 * Copyright (C) 2011 Matthias Klumpp
 *
 * Licensed under the GNU General Public License Version 3+
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
 */

using GLib;
using Listaller;

namespace Listaller.Extra {

private class AppPrepare : Object {
	private string srcdir;
	private string indir;
	private bool failed = false;

	public signal void error_message (string details);

	public AppPrepare (string input_dir) {
		indir = input_dir;
		srcdir = indir;
	}

	private void emit_error (string details) {
		error_message (details);
		failed = true;
	}

	public bool initialize () {
		// Check for valid installer source dirs
		srcdir = IPK.find_ipk_source_dir (srcdir);
		if (srcdir == null) {
			//: IPk builder was unable to find IPK source scripts
			emit_error (_("Could not find IPK source files!"));
			return false;
		}
		return true;
	}

	protected int run_target (string tname) {
		string buildfile;
		buildfile = Path.build_filename (srcdir, "build.rules", null);

		int exit_status = 0;
		try {
			string cmd = "make -f %s %s".printf (buildfile, tname);
			Process.spawn_command_line_sync	(cmd, null, null, out exit_status);
		} catch (SpawnError e) {
			emit_error (e.message);
			exit_status = 8;
		}
		return exit_status;
	}

	public int run_compile () {
		string lastdir = Environment.get_current_dir ();
		int code;
		code = run_target ("binary");
		Environment.set_current_dir (lastdir);
		return code;
	}

}

} // End of namespace
