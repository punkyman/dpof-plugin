/* Copyright 2011-2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

extern const string _VERSION;

//
// Each .so has a Spit.Module that describes the module and offers zero or more Spit.Pluggables
// to Shotwell to extend its functionality,
//

// taken from plugins/common/Resources.vala
public Gdk.Pixbuf[] ? load_icon_set(GLib.File ? icon_file)
{
	Gdk.Pixbuf ? icon = null;
	try {
		icon = new Gdk.Pixbuf.from_file(icon_file.get_path());
	} catch(Error err) {
		warning("couldn't load icon set from %s.",
			icon_file.get_path());
	}

	if (icon_file != null) {
		Gdk.Pixbuf[]icon_pixbuf_set = new Gdk.Pixbuf[0];
		icon_pixbuf_set += icon;
		return icon_pixbuf_set;
	}

	return null;
}

namespace Publishing.DPOF {

	public class DPOFPublisher:Spit.Publishing.Publisher, GLib.Object {

		private PublishingParameters publishing_parameters;
//		private PublishingOptionsPane ? publishing_options_pane = null;

		private weak Spit.Publishing.PluginHost host = null;
		private weak Spit.Publishing.Service service = null;
		private bool running = false;

		public DPOFPublisher(Spit.Publishing.Service service,
				     Spit.Publishing.PluginHost host) {
			debug("DPOFPublisher instantiated.");

			this.service = service;
			this.host = host;

			this.publishing_parameters = new PublishingParameters();
		}

        //Spit.Publishing.Publishable[] publishables = host.get_publishables();

        private void do_show_service_welcome_pane() {
			debug("ACTION: showing publishing options pane.");

			Gtk.Builder builder = new Gtk.Builder();

			try {
				builder.add_from_file(host.get_module_file
						      ().get_parent().get_child
						      ("dpof-pane.glade").get_path
						      ());
			} catch(Error e) {
				warning("Could not parse UI file! Error: %s.",
					e.message);
				host.post_error(new Spit.Publishing.
						PublishingError.LOCAL_FILE_ERROR
						("A file required for publishing is unavailable. Publishing to Youtube can't continue."));
				return;
			}

			/*publishing_options_pane = new PublishingOptionsPane(host, builder,
						      publishing_parameters);
			host.install_dialog_pane(publishing_options_pane);*/

			host.set_service_locked(false);
		}

		public Spit.Publishing.Service get_service() {
			return service;
		}

		public void start() {
			if (is_running())
				return;

			debug("DPOFPublisher: starting interaction.");

			running = true;

			// reset all publishing parameters to their default values -- in case this start is
			// actually a restart
			//publishing_parameters = new PublishingParameters();

			do_show_service_welcome_pane();
		}

		public void stop() {
			debug("DPOFPublisher: stop( ) invoked.");

			running = false;
		}

		public bool is_running() {
			return running;
		}
	}

private class PublishingParameters {
		private string ? path;

		public PublishingParameters() {
			this.path = null;
		}

		public string ? get_path() {
			return this.path;
		}

		public void set_path(string ? path) {
			this.path = path;
		}
	}
/*
	internal class PublishingOptionsPane:Spit.Publishing.DialogPane,
	    GLib.Object {
		private class PrivacyDescription {
			public string description;
			public PrivacySetting privacy_setting;

			public PrivacyDescription(string description,
						  PrivacySetting
						  privacy_setting) {
				this.description = description;
				this.privacy_setting = privacy_setting;
		}} public signal void publish();
		public signal void logout();

		private Gtk.Box pane_widget = null;
		private Gtk.ComboBoxText privacy_combo = null;
		private Gtk.Label publish_to_label = null;
		private Gtk.Label login_identity_label = null;
		private Gtk.Button publish_button = null;
		private Gtk.Button logout_button = null;
		private Gtk.Builder builder = null;
		private Gtk.Label privacy_label = null;
		private PrivacyDescription[] privacy_descriptions;
		private PublishingParameters publishing_parameters;

		public PublishingOptionsPane(Spit.Publishing.PluginHost host,
					     Gtk.Builder builder,
					     PublishingParameters
					     publishing_parameters) {
			this.privacy_descriptions =
			    create_privacy_descriptions();
			this.publishing_parameters = publishing_parameters;

			this.builder = builder;
			assert(builder != null);
			assert(builder.get_objects().length() > 0);

			login_identity_label =
			    this.
			    builder.get_object("login_identity_label") as Gtk.
			    Label;
			privacy_combo =
			    this.builder.
			    get_object("privacy_combo") as Gtk. ComboBoxText;
			publish_to_label =
			    this.builder.
			    get_object("publish_to_label") as Gtk. Label;
			publish_button =
			    this.builder.
			    get_object("publish_button") as Gtk. Button;
			logout_button =
			    this.builder.
			    get_object("logout_button") as Gtk. Button;
			pane_widget =
			    this.
			    builder.get_object("youtube_pane_widget") as Gtk.
			    Box;
			privacy_label =
			    this.builder.
			    get_object("privacy_label") as Gtk. Label;

			login_identity_label.set_label(_
						       ("You are logged into YouTube as %s.").printf
						       (publishing_parameters.get_user_name
							()));
			publish_to_label.
			    set_label("Videos will appear in '%s'".printf
				      (publishing_parameters.get_channel_name
				       ()));

			foreach(PrivacyDescription desc in privacy_descriptions) {
				privacy_combo.append_text(desc.description);
			}

			privacy_combo.set_active(PrivacySetting.PUBLIC);
			privacy_label.set_mnemonic_widget(privacy_combo);

			logout_button.clicked.connect(on_logout_clicked);
			publish_button.clicked.connect(on_publish_clicked);
		}

		private void on_publish_clicked() {
			publishing_parameters.set_privacy(privacy_descriptions
							  [privacy_combo.
							   get_active()].
							  privacy_setting);

			publish();
		}

		private void on_logout_clicked() {
			logout();
		}

		private void update_publish_button_sensitivity() {
			publish_button.set_sensitive(true);
		}

		private PrivacyDescription[] create_privacy_descriptions() {
			PrivacyDescription[]result = new PrivacyDescription[0];

			result +=
			    new PrivacyDescription("Public listed",
						   PrivacySetting.PUBLIC);
			result +=
			    new PrivacyDescription("Public unlisted",
						   PrivacySetting.UNLISTED);
			result +=
			    new PrivacyDescription("Private",
						   PrivacySetting.PRIVATE);

			return result;
		}

		public Gtk.Widget get_widget() {
			assert(pane_widget != null);
			return pane_widget;
		}

		public Spit.Publishing.
		    DialogPane.GeometryOptions get_preferred_geometry() {
			return Spit.Publishing.DialogPane.GeometryOptions.NONE;
		}

		public void on_pane_installed() {
			update_publish_button_sensitivity();
		}

		public void on_pane_uninstalled() {
		}
	}*/
}

private class DPOFPluginService:Object, Spit.Pluggable, Spit.Publishing.Service {
	private const string ICON_FILENAME = "dpof-plugin.png";
	private static Gdk.Pixbuf[] icon_pixbuf_set = null;

	public DPOFPluginService(GLib.File resource_directory) {
		if (icon_pixbuf_set == null)
			icon_pixbuf_set =
			    load_icon_set(resource_directory.get_child
					  (ICON_FILENAME));
	}
	public unowned string get_id() {
		return "org.punkyman.dpof-plugin";
	}

	public Spit.Publishing.Publisher.MediaType get_supported_media() {
		return (Spit.Publishing.Publisher.MediaType.PHOTO);
	}
	public Spit.Publishing.Publisher create_publisher(Spit.
							  Publishing.PluginHost
							  host) {
		return new Publishing.DPOF.DPOFPublisher(this, host);
	}

	public void get_info(ref Spit.PluggableInfo info) {
		info.authors = "Julien Reiss";
		info.version = _VERSION;
		info.is_license_wordwrapped = false;
		info.icons = icon_pixbuf_set;
	}
	public unowned string get_pluggable_name() {
		return "DPOF";
	}

	public int get_pluggable_interface(int min_host_interface,
					   int max_host_interface) {
		return Spit.negotiate_interfaces(min_host_interface,
						 max_host_interface,
						 Spit.
						 Publishing.CURRENT_INTERFACE);
	}

	public void activation(bool enabled) {
	}
}


private class DPOFPluginModule:Object, Spit.Module {
	private Spit.Pluggable[] pluggables = new Spit.Pluggable[0];

	public DPOFPluginModule(GLib.File module_file) {
		GLib.File resource_directory = module_file.get_parent();

		pluggables += new DPOFPluginService(resource_directory);
	} public unowned string get_module_name() {
		return "DPOF Plugin";
	}

	public unowned string get_version() {
		return _VERSION;
	}

	// Every module needs to have a unique ID.
	public unowned string get_id() {
		return "org.punkyman.dpof-plugin";
	}

	public unowned Spit.Pluggable[] ? get_pluggables() {
		return pluggables;
	}
}

//
// spit_entry_point() is required for all SPIT modules.
//

public Spit.Module ? spit_entry_point(Spit.EntryPointParams * params)
{
	// Spit.negotiate_interfaces is a simple way to deal with the parameters from the host
	params->module_spit_interface =
	    Spit.negotiate_interfaces(params->host_min_spit_interface,
				      params->host_max_spit_interface,
				      Spit.CURRENT_INTERFACE);

	return (params->module_spit_interface != Spit.UNSUPPORTED_INTERFACE)
	    ? new DPOFPluginModule(params->module_file) : null;
}

// This is here to keep valac happy.
private void dummy_main()
{
}
