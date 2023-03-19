#!/usr/bin/env nu

# '(")(?:[^"\\]|\\.)*(")' -> use rg

def extract_keys_and_values_from_json [
    path_to_json: string
] {
    rg -o -e '"(?:[^"\\]|\\.)*"' $path_to_json | lines | each {str trim -c '"' | str replace -a "%20" " "}
}

def extract_paths [
    path_to_json: string
    basedir: string
    relative_path: string
] {
    let keys_and_values = extract_keys_and_values_from_json $path_to_json
    mut paths = []
    for v in $keys_and_values {
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

    # Remove Playlist packs
    for playlist_packs in ($module.packs | where entity == Playlist) {
        let path_to_pack = ($module_base_dir | path join $playlist_packs.path)
        let playlist_paths = extract_paths $path_to_pack $module_base_dir $"modules/($module.name)"
        # Remove files
        verbose_remove_files $playlist_paths
        rm --force $path_to_pack
    }
    # Remove entries from module.json
    $module | update packs ($module.packs | where entity != Playlist) | save --force $module_path
    
    # Remove playlists embedded in adventures
    for adventure_pack in ($module.packs | where entity == Adventure) {
        let path_to_pack = ($module_base_dir | path join $adventure_pack)
        let adventure = (open $path_to_pack | from json)
        if "playlists" in $adventure {
            $adventure.playlists | save --force /tmp/adventure_playlist.json
            let playlist_paths = extract_paths /tmp/adventure_playlist.json $module_base_dir $"modules/($module.name)"
            # Remove playlist files
            verbose_remove_files $playlist_paths
            $adventure | update playlists [] | save --force $path_to_pack
        }
    }
}

def remove_journals [
    module_path: string
] {
    let module = open $module_path
    let module_base_dir = ($module_path | path dirname)

    # Remove Journal packs
    for journal_packs in ($module.packs | where entity == JournalEntry) {
        let path_to_pack = ($module_base_dir | path join $journal_packs.path)
        let journal_paths = extract_paths $path_to_pack $module_base_dir $"modules/($module.name)"
        # Remove files
        verbose_remove_files $journal_paths
        rm --force $path_to_pack
    }
    # Remove entries from module.json
    $module | update packs ($module.packs | where entity != JournalEntry) | save --force $module_path
    
    # Remove playlists embedded in adventures
    for adventure_pack in ($module.packs | where entity == Adventure) {
        let path_to_pack = ($module_base_dir | path join $adventure_pack)
        let adventure = (open $path_to_pack | from json)
        if "journal" in $adventure {
            $adventure.journal | save --force /tmp/adventure_journal.json
            let journal_paths = extract_paths /tmp/adventure_journal.json $module_base_dir $"modules/($module.name)"
            # Remove playlist files
            verbose_remove_files $journal_paths
            $adventure | update journal [] | save --force $path_to_pack
        }
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
    if not $journal {
        remove_journals $module_path
    }
}
