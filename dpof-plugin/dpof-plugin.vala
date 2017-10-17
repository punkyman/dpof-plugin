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

private class DPOFPluginService : Object, Spit.Pluggable, Spit.Publishing.Service {
        

    public DPOFPluginService() {
    }

    public unowned string get_id() {
        return "org.punkyman.dpof-plugin";
    }
    
    public Spit.Publishing.Publisher.MediaType get_supported_media() {
        return (Spit.Publishing.Publisher.MediaType.PHOTO);
    }
    public Spit.Publishing.Publisher create_publisher(Spit.Publishing.PluginHost host) {
        //TODO
        return null;
    }

    public void get_info(ref Spit.PluggableInfo info) {
        info.authors = "Julien Reiss";
        info.version = _VERSION;
        info.is_license_wordwrapped = false;
        
    }    
    public unowned string get_pluggable_name() {
        return "DPOF";
    }

    public int get_pluggable_interface(int min_host_interface, int max_host_interface) {
        return Spit.negotiate_interfaces(min_host_interface, max_host_interface,
            Spit.Publishing.CURRENT_INTERFACE);
    }
    
    public void activation(bool enabled) {
    }
}

private class DPOFPluginModule : Object, Spit.Module {
    private Spit.Pluggable[] pluggables = new Spit.Pluggable[0];

    public DPOFPluginModule()
    {
        pluggables += new DPOFPluginService();
    }

    public unowned string get_module_name() {
        return "DPOF Plugin";
    }
    
    public unowned string get_version() {
        return _VERSION;
    }
    
    // Every module needs to have a unique ID.
    public unowned string get_id() {
        return "org.punkyman.dpof-plugin";
    }
    
    public unowned Spit.Pluggable[]? get_pluggables() {
        return pluggables;
    }
}

//
// spit_entry_point() is required for all SPIT modules.
//

public Spit.Module? spit_entry_point(Spit.EntryPointParams *params) {
    // Spit.negotiate_interfaces is a simple way to deal with the parameters from the host
    params->module_spit_interface = Spit.negotiate_interfaces(params->host_min_spit_interface,
        params->host_max_spit_interface, Spit.CURRENT_INTERFACE);
    
    return (params->module_spit_interface != Spit.UNSUPPORTED_INTERFACE)
        ? new DPOFPluginModule() : null;
}

// This is here to keep valac happy.
private void dummy_main() {
}

