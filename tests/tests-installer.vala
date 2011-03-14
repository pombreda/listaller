/* tests-installer.vala
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

private string datadir;

void msg (string s) {
	stdout.printf (s + "\n");
}

void test_setup_message_cb (LiMessageItem item) {
	msg ("Received message:");
	msg (" " + item.to_string ());
	assert (item.mtype == LiMessageType.INFO);
}

void test_setup_error_code_cb (LiErrorItem item) {
	msg ("Received error:");
	msg (" " + item.to_string ());
	error (item.details);
}

void test_install_package () {
	bool ret = false;
	msg ("Installer tests");

	// Set up Listaller configuration
	LiSettings conf = new LiSettings ();
	conf.testmode = true;

	string ipkfilename = Path.build_filename (datadir, "foobar-testsetup.ipk", null);
	LiSetup setup = new LiSetup (ipkfilename, conf);
	ret = setup.initialize ();
	assert (ret == true);

	ret = setup.run_installation ();
	assert (ret == true);
}

int main (string[] args) {
	stdout.printf ("=== Running IPK Installer Tests ===\n");
	datadir = args[1];
	assert (datadir != null);
	datadir = Path.build_filename (datadir, "testdata", null);
	assert (FileUtils.test (datadir, FileTest.EXISTS) != false);

	Test.init (ref args);
	test_install_package ();
	Test.run ();
	return 0;
}
