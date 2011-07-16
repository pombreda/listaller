/* tests-depsolver.vala
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
using Listaller;

private string datadir;
private Listaller.Settings conf;

void msg (string s) {
	stdout.printf (s + "\n");
}

void test_solver_message_cb (MessageItem item) {
	msg ("Received message:");
	msg (" " + item.to_string ());
	assert (item.mtype != MessageEnum.CRITICAL);
}

void test_solver_error_code_cb (ErrorItem item) {
	msg ("Received error:");
	msg (" " + item.to_string ());
	error (item.details);
}

void test_dependency_manager () {
	msg ("Dependency manager tests");

	SoftwareDB sdb = new SoftwareDB (conf);
	sdb.error_code.connect (test_solver_error_code_cb);
	sdb.message.connect (test_solver_message_cb);

	// Do this only in testing environment!
	sdb.remove_db_lock ();
	// Open the DB
	sdb.open ();

	Deps.DepManager depman = new Deps.DepManager (sdb);

	IPK.Dependency test1 = new IPK.Dependency ("Test:1");
	test1.feed_url = "http://services.sugarlabs.org/libgee";

	depman.install_dependency (ref test1);
	assert (test1.satisfied == true);
	assert (test1.name == "libgee");

}

void search_install_pkdep (Deps.PkInstaller pkit, ref IPK.Dependency dep) {
	bool ret;
	ret = pkit.search_dep_packages (ref dep);
	if (!ret) {
		debug (pkit.last_error.details);
		assert (ret == true);
	}
	ret = pkit.install_dependency (ref dep);
	if (!ret) {
		debug (pkit.last_error.details);
		assert (ret == true);
	}
}

void test_packagekit_installer () {
	msg ("PackageKit dependency installer test");
	bool ret = false;

	// Build simple mp3gain dependency
	ArrayList<IPK.Dependency> deplist = new ArrayList<IPK.Dependency> ();
	IPK.Dependency depMp3Gain = new IPK.Dependency ("Mp3Gain");
	depMp3Gain.files.add ("/usr/bin/mp3gain");

	Deps.PkInstaller pkit = new Deps.PkInstaller (conf);
	pkit.message.connect (test_solver_message_cb);

	search_install_pkdep (pkit, ref depMp3Gain);
	assert (depMp3Gain.satisfied == true);

	// Now something more advanced
	IPK.Dependency crazy = new IPK.Dependency ("CrazyStuff");
	crazy.files.add ("/bin/bash");
	crazy.files.add ("libpackagekit-glib2.so");
	crazy.files.add ("libc6.so");

	search_install_pkdep (pkit, ref crazy);
	assert (crazy.satisfied == true);

	// Now something which fails
	IPK.Dependency fail = new IPK.Dependency ("Fail");
	fail.files.add ("/run/chicken");
	ret = pkit.search_dep_packages (ref fail);
	if (!ret) {
		debug (pkit.last_error.details);
		assert (ret == false);
	}
	assert (fail.satisfied == false);
}

void test_feed_installer () {
	msg ("ZI Feed installer tests");
	Deps.FeedInstaller finst = new Deps.FeedInstaller (conf);

	IPK.Dependency test1 = new IPK.Dependency ("Test:1");
	test1.feed_url = "http://services.sugarlabs.org/libvorbis";

	bool ret;
	ret = finst.install_dependency (ref test1);
	assert (ret == true);
	assert (test1.name == "libvorbis");

}

int main (string[] args) {
	msg ("=== Running Dependency Solver Tests ===");
	datadir = args[1];
	assert (datadir != null);
	datadir = Path.build_filename (datadir, "testdata", null);
	assert (FileUtils.test (datadir, FileTest.EXISTS) != false);

	Test.init (ref args);

	// Set up Listaller configuration
	conf = new Listaller.Settings ();
	conf.testmode = true;

	test_feed_installer ();
	//! test_packagekit_installer ();
	test_dependency_manager ();

	Test.run ();
	return 0;
}
