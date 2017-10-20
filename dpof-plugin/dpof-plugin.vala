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
		private PublishingLocationPane ? publishing_location_pane = null;

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

        private void do_show_pane() {
			debug("ACTION: showing publishing pane.");

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
						("A file required for publishing is unavailable. Publishing can't continue."));
				return;
			}

			publishing_location_pane = new PublishingLocationPane(host, builder,
						      publishing_parameters);

            publishing_location_pane.publish.connect(on_location_publish);

			host.install_dialog_pane(publishing_location_pane);

			host.set_service_locked(false);
		}

        private void on_location_publish() {
            debug("clicked OK, selected folder %s", publishing_parameters.get_path());

            if(!is_running())
                return;

            // since we are going to erase the content of the folder, make sure at least that the folder is a volume
            if(!publishing_parameters.get_path().has_prefix("/media/"))
                return;

            do_publish();
        }

        // recursively erase the content of a folder
        private void empty_folder(File folder)
        {
            FileEnumerator enumerator = null;
            FileInfo info = null;
            
            try
            {
                enumerator = folder.enumerate_children("standard::*",FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                info = enumerator.next_file();
            }
            catch (Error error) {
                   host.post_error(new Spit.Publishing.PublishingError.LOCAL_FILE_ERROR(error.message));
                   return;
            }

        	while (info != null) 
            {
                File enumerated_file = folder.resolve_relative_path (info.get_name ());
                string file_path = enumerated_file.get_path();
        		if (info.get_file_type () == FileType.DIRECTORY)
                {
                    empty_folder(enumerated_file);
                    Posix.rmdir(file_path);
                }
                else
                {
                    FileUtils.remove(file_path);
                }                

                try
                {
                    info = enumerator.next_file();
                }
                catch (Error error) {
                       host.post_error(new Spit.Publishing.PublishingError.LOCAL_FILE_ERROR(error.message));
                       return;
                }
    		}
        }

        private void do_publish()
        {
            host.set_service_locked(true);

            host.serialize_publishables(-1);
            Spit.Publishing.Publishable[] publishables = host.get_publishables();

            File folder = File.new_for_path(publishing_parameters.get_path());

            empty_folder(folder);
            
            // copy selected pictures in the destination folder
            for(int i = 0; i < publishables.length; ++i)
            {
                Spit.Publishing.Publishable? pub = publishables[i];

                debug("DPOFPublisher: got a publishable with name %s", pub.get_publishing_name());
                File? source = pub.get_serialized_file();

                if(source == null)
                    continue;

                debug("DPOFPublisher: copying file %s.", source.get_path());

                File dest = File.new_for_path(publishing_parameters.get_path() + "/" + source.get_basename());
                try
                {
                    source.copy(dest, 0, null, null);
                }
                catch (Error error) {
                    host.post_error(new Spit.Publishing.PublishingError.LOCAL_FILE_ERROR(error.message));
                    return;
                }
            }

            // create the DPOF standard data
            Posix.mkdir(publishing_parameters.get_path() + "/MISC", Posix.S_IRWXU | Posix.S_IRWXG | Posix.S_IRWXO);
            File dpof_infos = File.new_for_path(publishing_parameters.get_path() + "/MISC/AUTPRINT.MRK");
            FileOutputStream os = null;
                      
            try
            {
                os = dpof_infos.create (FileCreateFlags.NONE);
    
                string fake_dpof_header = "[HDR]\r\nGEN REV = 01.00\r\nGEN CRT = \"SONY CYBERSHOT\"\r\nGEN DTM = 2017:10:16:13:20:27\r\n";
                os.write(fake_dpof_header.data);
            }
            catch (Error error) {
                host.post_error(new Spit.Publishing.PublishingError.LOCAL_FILE_ERROR(error.message));
                return;
            }

            for(int i = 0; i < publishables.length; ++i)
            {
                Spit.Publishing.Publishable? pub = publishables[i];
                File? source = pub.get_serialized_file();
                
                string publishable_dpof_data = "\r\n[JOB]\r\nPRT PID = " + (i+1).to_string("%03i") + "\r\nPRT TYP = STD\r\nIMG FMT = EXIF2 -J\r\n<IMG SRC = \"../" + source.get_basename() + "\">\r\n";

                try
                {
                    os.write(publishable_dpof_data.data);
                }
                catch (Error error) {
                   host.post_error(new Spit.Publishing.PublishingError.LOCAL_FILE_ERROR(error.message));
                   return;
               }
            }            

            try
            {
                os.close();
            }
            catch (Error error) {
                host.post_error(new Spit.Publishing.PublishingError.LOCAL_FILE_ERROR(error.message));
                return;
            }

            host.set_service_locked(false);
            host.install_success_pane();
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
			publishing_parameters = new PublishingParameters();

			do_show_pane();
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

	internal class PublishingLocationPane : Spit.Publishing.DialogPane,
	    GLib.Object {
        
        public signal void publish();

        private Gtk.Builder builder = null;

		private Gtk.Box file_widget = null;
		private Gtk.FileChooserWidget file_chooser = null;
		private Gtk.Button ok_button = null;
		private PublishingParameters publishing_parameters;

		public PublishingLocationPane(Spit.Publishing.PluginHost host,
					     Gtk.Builder builder,
					     PublishingParameters
					     publishing_parameters) {
			this.publishing_parameters = publishing_parameters;

			this.builder = builder;
			assert(builder != null);
			assert(builder.get_objects().length() > 0);

            file_widget  =
			    this.
			    builder.get_object("DPOFFileChooser") as Gtk.Box;

			file_chooser =
			    this.
			    builder.get_object("FileChooserWidget") as Gtk.FileChooserWidget;

			ok_button =
			    this.builder.
			    get_object("OkButton") as Gtk.Button;

			ok_button.clicked.connect(on_publish_clicked);
		}

		private void on_publish_clicked() {
			publishing_parameters.set_path(file_chooser.get_filename());

			publish();
		}

		private void update_publish_button_sensitivity() {
			ok_button.set_sensitive(true);
		}

		public Gtk.Widget get_widget() {
			assert(file_widget != null);
			return file_widget;
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
	}
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
