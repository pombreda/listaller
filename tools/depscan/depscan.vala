/* depscan.vala
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

public interface IDepScanEngine {
	public abstract ArrayList<string> required_files ();
	public abstract bool can_be_used (string fname);
	public abstract bool fetch_required_files (string fname);
}

private class DependencyScanner : Object {
	private string targetdir;
	private HashSet<string> requires;
	public bool recursive { get; set; }

	public HashSet<string> required_files {
		get { return requires; }
	}

	public DependencyScanner (string target_dir) {
		targetdir = target_dir;
		requires = new HashSet<string> ();
	}

	private ArrayList<string>? get_file_list (string dir) {
		ArrayList<string> list = new ArrayList<string> ();
		try {
			var directory = File.new_for_path (dir);

			var enumerator = directory.enumerate_children (FILE_ATTRIBUTE_STANDARD_NAME, 0);

			FileInfo file_info;
			while ((file_info = enumerator.next_file ()) != null) {
				string path = Path.build_filename (dir, file_info.get_name (), null);
				if ((FileUtils.test (path, FileTest.IS_SYMLINK)) || (file_info.get_is_hidden ()))
					continue;
				if ((!FileUtils.test (path, FileTest.IS_REGULAR)) && (recursive)) {
					ArrayList<string> subdir_list = get_file_list (path);
					// There was an error, exit
					if (subdir_list == null)
						return null;
					list.add_all (subdir_list);
				} else {
					// Presort files here
					bool uncertain = false;
					string ctype = ContentType.guess (path, null, out uncertain);
					if ((ContentType.can_be_executable (ctype)) ||
						FileUtils.test (path, FileTest.IS_EXECUTABLE))
						list.add (path);
				}
			}

		} catch (Error e) {
			stderr.printf (_("Error: %s\n"), e.message);
			return null;
		}
		return list;
	}

	private void scan_engine_process (ArrayList<string> files, IDepScanEngine eng) {
		foreach (string s in files) {
			if (eng.can_be_used (s))
			if (eng.fetch_required_files (s)) {
				requires.add_all (eng.required_files ());
			}
		}
	}

	public bool compile_required_files_list () {
		requires.clear ();
		stdout.printf ("Please wait...");
		ArrayList<string> files;
		if (FileUtils.test (targetdir, FileTest.IS_REGULAR)) {
			files = new ArrayList<string> ();
			files.add (targetdir);
		} else {
			files = get_file_list (targetdir);
		}
		if (files == null)
			return false;

		// Process binaries
		scan_engine_process (files, new DepscanLDD ());

		stdout.printf ("\r");
		// TODO: Finish this...
		foreach (string s in requires) {
			stdout.printf (s + "\n");
		}
		return true;
	}
}
