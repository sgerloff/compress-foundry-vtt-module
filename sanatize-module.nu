#!/usr/bin/env nu

def main [
    module_path: string
    --prepend-title: string = ""
    --drop-packs: list<any> = ["playlists", "journal"]
    --drop-keys: list = ["path", "src"]
] {
    let module = open $"$module_path/module.json"
    let file_list = []
    for pack in $module.packs {
        let pack_path = pack.path
        let pack_data = (open $pack_path | from json)
        for key in $drop-packs {
            for sub_pack in  ($pack_data | get -i $key) {
                for drop_key in $drop-keys {
                    $file_list | append | $sub_pack | get -i $drop_key
                }
            }
        }
    }
    $file_list
}
