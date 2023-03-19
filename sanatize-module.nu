#!/usr/bin/env nu

# '(")(?:[^"\\]|\\.)*(")' -> use rg

def clean_paths [
    input_string: string
] {
    if ($input_string | str contains "/") {
        return ($input_string | str trim -c '"' | urlencode -d $in)
    } else {
        return ($input_string | str trim -c '"')
    }
}

def extract_keys_and_values_from_json [
    path_to_json: string
] {
    rg -o -e '"(?:[^"\\]|\\.)*"' $path_to_json | lines | each {|in| clean_paths $in}
}

def extract_paths [
    path_to_json: string
    basedir: string
    relative_path: string
] {
    let keys_and_values = extract_keys_and_values_from_json $path_to_json
    mut paths = []
    for v in $keys_and_values {
        if ($v | str contains "/") {
            let relative_potential_path = do -i {$v | path relative-to $relative_path}
            if ($relative_potential_path | describe | str contains string) {
                let potential_path = ($basedir | path join $relative_potential_path)
                if ($potential_path | path exists) {
                    if ($potential_path | path type | $in == file) {
                        $paths = ($paths | append $potential_path)
                    }
                }
            }
        }
    }
    return $paths
}

def verbose_remove_files [
    list_of_files
] {
    for file in $list_of_files {
        print $"Remove: ($file)"
        rm --force $file
    }
}

def remove_playlists [
    module_path: string 
] {
    let module = open $module_path
    let module_base_dir = ($module_path | path dirname)

    mut to_remove_paths = []

    # Remove Playlist packs
    for playlist_packs in ($module.packs | where entity == Playlist) {
        let path_to_pack = ($module_base_dir | path join $playlist_packs.path)
        rm --force $path_to_pack
    }
    # Remove entries from module.json
    $module | update packs ($module.packs | where entity != Playlist) | save --force $module_path
    
    # Remove playlists embedded in adventures
    for adventure_pack in ($module.packs | where entity == Adventure) {
        let path_to_pack = ($module_base_dir | path join $adventure_pack)
        let adventure = (open $path_to_pack | from json)
        if "playlists" in $adventure {
            $adventure | update playlists [] | save --force $path_to_pack
        }
    }
}

def remove_journals [
    module_path: string
] {
    let module = open $module_path
    let module_base_dir = ($module_path | path dirname)

    mut to_remove_paths = []

    # Remove Journal packs
    for journal_packs in ($module.packs | where entity == JournalEntry) {
        let path_to_pack = ($module_base_dir | path join $journal_packs.path)
        rm --force $path_to_pack
    }
    # Remove entries from module.json
    $module | update packs ($module.packs | where entity != JournalEntry) | save --force $module_path
    
    # Remove playlists embedded in adventures
    for adventure_pack in ($module.packs | where entity == Adventure) {
        let path_to_pack = ($module_base_dir | path join $adventure_pack)
        let adventure = (open $path_to_pack | from json)
        if "journal" in $adventure {
            $adventure | update journal [] | save --force $path_to_pack
        }
    }
    return $to_remove_paths
}

def remove_unused [
    module_path: string 
] {
    let module = open $module_path
    let module_base_dir = ($module_path | path dirname)

    let used_packs_paths = ($module.packs.path | each {|it| $module_base_dir | path join $it})
    let packs_dir = ($module_base_dir | path join packs)
    for pack_file in (fd -t f . $packs_dir) {
        if not $pack_file in $used_packs_paths {
            rm --force $pack_file
        }
    }

    mut used_paths = $used_packs_paths
    $used_paths = ($used_paths | append $module_path)

    for used_pack in $used_packs_paths {
        print $"Gather paths from ($used_pack)..."
        let paths = extract_paths $used_pack $module_base_dir $"modules/($module.name)"
        $used_paths = ($used_paths | append $paths)
    }

    for $file in (fd -t f . $module_base_dir | lines) {
        if not $file in $used_paths {
            print $"Remove unused file: ($file)"
            rm --force $file
        }
    }
}

def main [
    module_path: string # path to module.json
    --prepend-title: string = "" # prepend string to module title
    --playlist (-p) # keep playlists from module
    --journal (-j) # keep journals from module
] {
    mut to_remove_paths = []

    if not $playlist {
        remove_playlists $module_path
    }
    if not $journal {
        remove_journals $module_path
    }

    remove_unused $module_path
}
