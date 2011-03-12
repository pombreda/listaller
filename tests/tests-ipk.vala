/* tests-ipk.vala
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

void test_ipk_message_cb (LiMessageItem item) {
	msg ("Received message:");
	msg (" " + item.to_string ());
	assert (item.mtype == LiMessageType.INFO);
}

void test_ipk_error_code_cb (LiErrorItem item) {
	msg ("Received error:");
	msg (" " + item.to_string ());
	error (item.details);
}

void test_ipk_package () {
	bool ret = false;
	msg ("Package tests");

	// Set up Listaller configuration
	LiSettings conf = new LiSettings ();
	conf.testmode = true;

	string ipkfilename = Path.build_filename (datadir, "foobar-testsetup.ipk", null);
	msg ("Loading IPK package %s".printf (ipkfilename));
	IPKPackage ipk = new IPKPackage (ipkfilename, conf);
	// Connect signal handlers
	ipk.message.connect (test_ipk_message_cb);
	ipk.error_code.connect (test_ipk_error_code_cb);

	ret = ipk.initialize ();
	assert (ret == true);
	assert (ipk.control.get_app_name () == "FooBar");

	ArrayList<IPKFileEntry> flist = ipk.get_filelist ();
	foreach (IPKFileEntry e in flist) {
		bool inst_ok = ipk.install_file (e);
		assert (inst_ok == true);
	}
}

void test_ipk_control_file () {
	msg ("Controlfile tests");
	IPKControl ipkc = new IPKControl ();
	ipkc.create_new ();
	ipkc.set_app_name ("echoecho");
	ipkc.set_pkg_id ("echo-123");

	ArrayList<string> list = new ArrayList<string> ();
	list.add ("alpha");
	list.add ("beta");
	list.add ("gamma");
	list.add ("delta");
	ipkc.set_pkg_dependencies (list);

	// ipkc.print_xml ();

	assert (ipkc.get_app_name () == "echoecho");
	assert (ipkc.get_pkg_id () == "echo-123");
}

void test_ipk_filelist_file () {
	msg ("Filelist tests.");
	bool ret = false;

	IPKFileList flist = new IPKFileList ();
	ret = flist.add_file (Path.build_filename (datadir, "dummy-control.xml", null), "$INST/+junk");
	assert (ret == true);
	ret = flist.add_file (Path.build_filename (datadir, "foo-payload", "appdata", "+junk", "packicon.png", null), "$INST/+junk");
	assert (ret == true);
	ret = flist.add_file (Path.build_filename (datadir, "foo-payload", "desktop", "Osmos.desktop", null), "$APP");
	assert (ret == true);

	string tmpfile = Path.build_filename (datadir, "sample-files.list", null);
	FileUtils.remove (tmpfile);
	flist.save (tmpfile);

	ArrayList<IPKFileEntry> lst = flist.get_files ();
	foreach (IPKFileEntry e in lst) {
		msg (e.to_string ());
	}
}

int main (string[] args) {
	stdout.printf ("=== Running IPK Tests ===\n");
	datadir = args[1];
	assert (datadir != null);
	datadir = Path.build_filename (datadir, "testdata", null);
	assert (FileUtils.test (datadir, FileTest.EXISTS) != false);

	Test.init (ref args);
	test_ipk_control_file ();
	test_ipk_filelist_file ();
	test_ipk_package ();
	Test.run ();
	return 0;
}
