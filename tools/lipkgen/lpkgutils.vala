/* lpkgutils.vala -- Helper routines for LiPkgen
 *
 * Copyright (C) 2012-2014 Matthias Klumpp <matthias@tenstral.net>
 *
 * Licensed under the GNU General Public License Version 3
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

namespace Listaller.IPK {

	private string? validate_srcdir (string dir) {
		// Check if IPK sources are present
		string tmp = dir;
		if (FileUtils.test (tmp, FileTest.IS_DIR)) {
			if (FileUtils.test (Path.build_filename (tmp, "pkoptions", null), FileTest.EXISTS)) {
				// Set current source dir and exit
				return tmp;
				}
		}
		return null;
	}

	private string? find_ipk_source_dir (string origdir) {
		string tmp = validate_srcdir (Path.build_filename (origdir, "ipkinstall", null));
		if (tmp == null) {
			tmp = validate_srcdir (Path.build_filename (origdir, "install", null));
			if (tmp == null) {
				tmp = validate_srcdir (Path.build_filename (origdir, "data", "install", null));
			}
		}
		return tmp;
	}

} // End of namespace

private static void pkbuild_action (string msg, bool header = false) {
	string output_txt = "";
	if (header)
		output_txt = "== %s ==\n".printf (msg);
	else
		output_txt = " - %s\n".printf (msg);

	stdout.printf (output_txt);
}
