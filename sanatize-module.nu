#!/usr/bin/env nu

# '(")(?:[^"\\]|\\.)*(")' -> use rg

def extract_paths [
    path_to_json: string
    basedir: string
    relative_path: string
] {
    let keys_and_values = (rg -o -e '"(?:[^"\\]|\\.)*"' $path_to_json | lines | each {str trim -c '"'})
    let paths = []
    for v in $keys_and_values {
        let relative_potential_path = do -i {$v | path relative-to $relative_path}
        if ($relative_potential_path | describe | str contains string) {
            let potential_path = ($basedir | path join $relative_potential_path)
            print $potential_path
            if ($potential_path | path exists) {
                if ($potential_path | path type | $in == file) {
                    paths | append $potential_path
                }
            }
        }
    }
    $paths
}

def remove_playlists [
    module_path: string 
] {
    let module = open $module_path
    let module_base_dir = ($module_path | path dirname)

    for playlist_packs in ($module.packs | where entity == Playlist) {
        let path_to_pack = ($module_base_dir | path join $playlist_packs.path)
        let playlist_paths = extract_paths $path_to_pack $module_base_dir $"modules/($module.name)"
        print $playlist_paths
    }

    for adventure_packs in ($module.packs | where entity == Adventure) {

    }
}

def main [
    module_path: string # path to module.json
    --prepend-title: string = "" # prepend string to module title
    --playlist (-p) # keep playlists from module
    --journal (-j) # keep journals from module
] {
    if not $playlist {
        remove_playlists $module_path
    }
}
