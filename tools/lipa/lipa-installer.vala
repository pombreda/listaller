/* lipa-installer.vala -- Application setup handling in Listaller command-line tool
 *
 * Copyright (C) 2010-2014 Matthias Klumpp <matthias@tenstral.net>
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

using GLib;
using Listaller;

public class LipaInstaller : LipaModule {
	private Setup inst;
	private bool setup_running = false;

	public LipaInstaller () {
		base ();
	}

	public void setup_error_code (ErrorItem error) {
		// End progress, if any
		progress_bar.end ();

		stderr.printf ("%s\n", error.details);
		error_code = (int) error.error;
	}

	public void setup_progress (ProgressItem item) {
		int value = item.value;
		if (value < 0)
			return;
		if (item.prog_type != ProgressEnum.MAIN_PROGRESS)
			return;

		if (setup_running)
			progress_bar.set_percentage (item.value);

		// TODO: Show item-progress too
	}

	public void setup_status_changed (StatusItem status) {
		if (status.status == StatusEnum.INSTALLATION_FINISHED) {
			progress_bar.end ();
			print ("%s\n", _("Installation completed!"));
			setup_running = false;
		} else if (status.status == StatusEnum.ACTION_STARTED) {
			setup_running = true;
		}
	}

	public void setup_message (MessageItem message) {
		stdout.printf ("%s\n", message.details);
	}

	public void run_setup (Setup inst) {
		bool ret;
		print ("Preparing... Please wait!\r");

		inst.message.connect (setup_message);
		inst.status_changed.connect (setup_status_changed);
		inst.progress.connect (setup_progress);
		inst.error_code.connect (setup_error_code);

		ret = inst.initialize ();
		if (!ret) {
			error_code = 8;
			return;
		}

		IPK.Control ipkmeta = inst.control;
		if (ipkmeta == null) {
			error_code = 6;
			return;
		}

		if (use_shared_mode) {
			IPK.InstallMode modes = inst.supported_install_modes ();
			if (modes.is_all_set (IPK.InstallMode.SHARED))
				inst.settings.current_mode = IPK.InstallMode.SHARED;
			else {
				// TODO: Nicer error-handling
				error ("You cannot install this package in shared-mode! (Package does not allow it.)");
			}
		}

		AppItem app = ipkmeta.get_application ();
		//print ("%c8", 0x1B);
		print ("==== %s ====\n\n", _("Installation of %s").printf (app.info.name));

		print ("%s\n\n%s\n", _("Description:"), app.info.description);

		if (ipkmeta.user_accept_license) {
			string[] licenseLines = app.license.text.split ("\n");

			// save cursor in new position
			//print ("%c7", 0x1B);

			bool clear_hint = false;
			if (licenseLines.length > 1) {
				// translations might have a different length
				string clear_line = string.nfill (_("<<< Press ENTER to continue! >>>").length, ' ');
				clear_line = "\r  %s  \r".printf (clear_line);

				print ("%s\n\n", _("License:"));
				for (int i = 0; i < licenseLines.length; i++) {
					if (clear_hint) {
						// clear the "press-enter"-link
						stdout.printf (clear_line);
						clear_hint = false;
					}
					stdout.printf ("%s\n", licenseLines[i]);
					if ((i % 2) == 1) {
						Posix.FILE? tty = console_get_tty ();
						stdout.printf (" %s \r", _("<<< Press ENTER to continue! >>>"));
						clear_hint = true;
						console_wait_for_enter (tty);
					}
				}
				ret = console_get_prompt (_("Do you accept these terms and conditions?"), false, true);
				// if user doesn't agree to the license, we have to exit
				if (!ret) {
					stdout.printf ("%s\n", _("You need to agree with the license to install & use the application. Exiting setup now."));
					return;
				}
			}
		}

		// Display security info
		IPK.SecurityInfo sec = inst.get_security_info ();
		SecurityLevel secLev = sec.get_level ();
		if (secLev == SecurityLevel.HIGH)
			print ("%s %c[%dm%s\n%c[%dm", _("Security is:"), 0x1B, CONSOLE_GREEN, "HIGH", 0x1B, CONSOLE_RESET);
		else if (secLev == SecurityLevel.MEDIUM)
			print ("%s %c[%dm%s\n%c[%dm", _("Security is:"), 0x1B, CONSOLE_YELLOW, "MEDIUM", 0x1B, CONSOLE_RESET);
		else if (secLev <= SecurityLevel.LOW)
			print ("%s %c[%dm%s\n%c[%dm", _("Security is:"), 0x1B, CONSOLE_RED, "LOW", 0x1B, CONSOLE_RESET);

		// Make sure color is reset...
		print ("%c[%dm", 0x1B, CONSOLE_RESET);

		app = inst.get_current_application ();
		if (app == null)
			error ("Did not receive valid application information!");

		ret = console_get_prompt (_("Do you want to install %s now?").printf (app.info.name), true);
		// If user doesn't want to install the application, exit
		if (!ret)
			return;

		progress_bar.start (_("Installing"));
		// Go!
		ret = inst.run_installation ();
		progress_bar.end ();

		if (ret) {
			print ("Installation of %s completed successfully!\n", app.info.name);
		} else {
			print ("Installation of %s failed!\n", app.info.name);
			error_code = 3;
		}

		inst = null;
	}

	public void install_package (string ipkfname) {
		inst = new Setup (ipkfname);
		run_setup (inst);
	}

	public override void terminate_action () {
		if (inst != null) {
			if (setup_running)
				inst.kill_installation_process ();
			inst = null;
		}
	}

}
