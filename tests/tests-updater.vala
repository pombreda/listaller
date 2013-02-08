/* tests-updater.vala
 *
 * Copyright (C) 2012-2013 Matthias Klumpp <matthias@tenstral.net>
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
 * 	Matthias Klumpp <matthias@tenstral.net>
 */

using GLib;
using Gee;
using Listaller;

private string datadir;

void msg (string s) {
	stdout.printf (s + "\n");
}

void test_upd_message_cb (MessageItem item) {
	msg ("Received message:");
	msg (" " + item.to_string ());
	assert (item.mtype == MessageEnum.INFO);
}

void test_upd_error_code_cb (ErrorItem item) {
	msg ("Received error:");
	msg (" " + item.to_string ());
	// skip all permission-errors
	if (item.error != ErrorEnum.OPERATION_NOT_ALLOWED)
		error (item.details);
}

void print_app_arraylist (ArrayList<AppItem> appList, string label = "") {
	if (label != "")
		msg ("Application List [%s]:".printf (label));
	else
		msg ("Application List:");

	foreach (AppItem app in appList) {
		stdout.printf ("%s\n", app.to_string ());
	}
	msg ("END");
}

void test_foobar_installation () {
	bool ret;
	string ipkfilename = Path.build_filename (datadir, "FooBar-1.0_%s.ipk".printf (Utils.system_machine_generic ()), null);

	// Excludes stuff like PK dependency installing from testing
	__unittestmode = true;
	Report.set_print_fatal_msg (false);

	Setup setup = new Setup (ipkfilename);
	setup.error_code.connect (test_upd_error_code_cb);
	setup.message.connect (test_upd_message_cb);

	ret = setup.initialize ();
	assert (ret == true);

	ret = setup.set_install_mode (IPK.InstallMode.TEST);
	assert (ret == true);

	ret = setup.run_installation ();
	assert (ret == true);
}

void test_manager_installed_apps () {
	Manager mgr = new Manager ();
	mgr.settings.current_mode = IPK.InstallMode.TEST;

	ArrayList<AppItem> app_list;
	mgr.filter_applications (AppState.INSTALLED_SHARED | AppState.INSTALLED_PRIVATE, out app_list);
	print_app_arraylist (app_list, "Installed apps (pre-update)");
	// we should have exactly 1 app installed (FooBar)
	assert (app_list.size == 1);

	// test version
	assert (app_list[0].version == "1.0");
}

void test_refresh_repo_cache () {
	// refresh app cache
	Repo.Manager repomgr = new Repo.Manager ();
	repomgr.refresh_cache ();

	// check new app info
	Manager mgr = new Manager ();
	mgr.settings.current_mode = IPK.InstallMode.TEST;

	ArrayList<AppItem> app_list;
	mgr.filter_applications (AppState.AVAILABLE, out app_list);
	print_app_arraylist (app_list, "Available apps");
	// we should now have more than one app
	assert (app_list.size > 1);
}

void test_updater_update () {
	Updater upd = new Updater (false);
	upd.settings.current_mode = IPK.InstallMode.TEST;
	upd.find_updates ();

	message ("Found updates: %i", upd.available_updates.size);
	assert (upd.available_updates.size >= 1);

	upd.apply_updates_all ();

	foreach (UpdateItem item in upd.available_updates)
		assert (item.completed == true);

	upd.find_updates ();
	assert (upd.available_updates.size == 0);

	// now test installed apps *after* update (version should have been increased)
	Manager mgr = new Manager ();
	mgr.settings.current_mode = IPK.InstallMode.TEST;

	ArrayList<AppItem> app_list;
	mgr.filter_applications (AppState.INSTALLED_SHARED | AppState.INSTALLED_PRIVATE, out app_list);
	print_app_arraylist (app_list, "Installed apps (post-update)");
	// we should still have exactly 1 app installed
	assert (app_list.size == 1);

	// test version
	assert (app_list[0].version == "1.1");
}


int main (string[] args) {
	msg ("=== Running Updater Tests ===");
	datadir = args[1];
	assert (datadir != null);
	datadir = Path.build_filename (datadir, "testdata", null);
	assert (FileUtils.test (datadir, FileTest.EXISTS) != false);

	Test.init (ref args);
	set_console_mode (true);
	set_verbose_mode (true);
	add_log_domain ("LiTest");

	// prepare updater environment
	test_foobar_installation ();
	test_manager_installed_apps ();

	// perform updater tests
	test_refresh_repo_cache ();
	test_updater_update ();

	Test.run ();
	return 0;
}
