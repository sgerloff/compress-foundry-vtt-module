#!/usr/bin/env nu

use utils [extract_content_from_json, verbose_remove_files, compress_image_webp, get_output_path_webp, is_image_file]

def extract_paths [
    path_to_json: string
    relative_path: string
] {
    let content = extract_content_from_json $path_to_json

    mut paths = []
    for c in $content {
        if not ($c | str contains ".") {
            continue
        }

        let relative_potential_path = do -i {$c | path relative-to $relative_path}
        if ($relative_potential_path | is-empty) {
            continue
        }
        $paths = ($paths | append $relative_potential_path)
    }
    return ($paths | uniq)
}

def rename_deprecated_fields [
    module
] {
    mut updated_module = $module
    mut updated_packs = []
    for pack in $module.packs {
        let updated_pack = ($pack | update path ($pack.path | str trim -l -c "/"))
        if ("entity" in ($pack | columns)) {
            $updated_packs = ($updated_packs | prepend ($updated_pack | rename -c [entity, type]))
        } else {
            $updated_packs = ($updated_packs | prepend $updated_pack)
        }
    }
    $updated_module = ($updated_module | update "packs" $updated_packs)
    return $updated_module
}

def remove_components_from_module [
    module,
    module_base_dir: string,
    to_remove_components
] {
    mut updated_module = $module
    for component in $to_remove_components {
        # Remove related packs
        for pack in ($module.packs | where type == $component.pack_type) {
            let path_to_pack = ($module_base_dir | path join $pack.path)
            verbose_remove_files [$path_to_pack]
        }
        # Remove entries from module.json
        $updated_module = ($updated_module | update packs ($module.packs | where type != $component.pack_type))
        # Remove components embedded in adventures
        for adventure_pack in ($module.packs | where type == Adventure) {
            let path_to_pack = ($module_base_dir | path join $adventure_pack.path)
            mut adventure = (open $path_to_pack | from json)
            if $component.adventure_field in $adventure {
                $adventure = ($adventure | update $component.adventure_field [])
            }
            $adventure | to json -r | save -f $path_to_pack
        }
    }
    return $updated_module
}


def remove_unused_packs [
    module,
    module_base_dir: string
] {
    let used_packs_paths = ($module.packs.path | each {|it| $module_base_dir | path join $it})
    let packs_dir = ($module_base_dir | path join packs)
    for pack_file in (fd -t f . $packs_dir | lines) {
        if not $pack_file in $used_packs_paths {
            verbose_remove_files [$pack_file]
        }
    }
    $module | update packs ($module.packs | filter {|it| $module_base_dir | path join $it.path | path exists})
}

def extract_used_paths [
    module,
    module_base_dir: string
    module_files
] {
    mut used_paths = [{path: module.json, abs_decoded_path: ($module_base_dir | path join module.json)}]
    for packs_path in $module.packs.path {
        $used_paths = ($used_paths | append {path: $packs_path, abs_decoded_path: ($module_base_dir | path join $packs_path)})
    }

    let used_packs_paths = ($module.packs.path | each {|it| $module_base_dir | path join $it})
    for used_pack in $used_packs_paths {

        mut module_dir_name = ""
        if ($module | get -i name | is-empty) {
            $module_dir_name = $module.id
        } else {
            $module_dir_name = $module.name
        }
        let potential_paths = extract_paths $used_pack $"modules/($module_dir_name)"

        for potential_path in $potential_paths {
            let potential_decoded_path = ($module_base_dir | path join $potential_path | urlencode -d $in )
            if $potential_decoded_path in $module_files {
                $used_paths = ($used_paths | append {path: $potential_path, abs_decoded_path: $potential_decoded_path})
            }
        }
    }
    return $used_paths
}


def image_cleanup_step [
    root_path: string
    input_path: string
    output_path: string
] {
    if ($input_path | str ends-with '.webp') {
        mv -f $output_path $input_path
    } else {
        let relative_input_path = ($input_path | path relative-to $root_path)
        let relative_output_path = ($output_path | path relative-to $root_path)
        print $"Replace ($relative_input_path) -> ($relative_output_path)"
        rg -l $relative_input_path $root_path | lines | each { 
            sd $relative_input_path $relative_output_path $in
        }
        rm $input_path
    }
}

def generate_preview_images [
    used_paths,
    module_base_dir : string,
    prepend_string: string,
    preview_path: string,
    preview_size: int,
    quality: int
] {
    mkdir $preview_path

    let map_dirs = (["map", "scene"] | each {|it| fd -t d $it $module_base_dir | lines} | flatten)
    let map_files = ($map_dirs | each {|it| fd -t f . $it | lines} | flatten)

    for used_path in $used_paths {
        if not ($used_path.abs_decoded_path | path exists) {
            continue
        }

        if not (is_image_file $used_path.abs_decoded_path) {
            continue
        }

        if $used_path.abs_decoded_path in $map_files {
            print $"Generate preview for ($used_path.path)"
            let output_file_name = ([$prepend_string, (basename $used_path.abs_decoded_path)] | str join "_" | path parse | update extension webp | path join)
            cwebp -mt -progress -short -resize $preview_size 0 -q $quality $used_path.abs_decoded_path -o ($preview_path | path join $output_file_name)
        }
    }
}


def compress_used_images [
    used_paths,
    module_base_dir,
    quality: int 
] {
    for used_path in $used_paths {
        if not ($used_path.abs_decoded_path | path exists) {
            continue
        }

        if not (is_image_file $used_path.abs_decoded_path) {
            continue
        }
        let output_path = get_output_path_webp $used_path.path
        let output_abs_path = get_output_path_webp $used_path.abs_decoded_path
        compress_image_webp $used_path.abs_decoded_path $output_abs_path --quality $quality

        if ($used_path.abs_decoded_path | str ends-with '.webp') {
            mv -f $output_abs_path $used_path.abs_decoded_path
        } else {
            print $"Replace ($used_path.path) -> ($output_path)"
            rg -l $used_path.path $module_base_dir | lines | each { 
                sd $used_path.path $output_path $in
            }
            verbose_remove_files [$used_path.abs_decoded_path]
        }
    }
}

def main [
    module_url: string # path to module.json
    --output-dir: string = "" # location for compressed module zip file
    --prefix: string = "" # if provided prepended to the title for easy grouping
    --quality: int = 25 # quality of webp images [0..100], where 100 is best
    --preview (-P): string = "" # generate previews and save to path
    --preview-size (-S): int = 1000 # max size of preview images
    --playlist (-p) # keep playlists from module
    --journal (-j) # keep journals from module
    --force (-f) # overwrite output file
] {
    mut module = (http get $module_url | from json)

    let download_dir = (mktemp -d)
    let download_path = $"($download_dir)/module.zip"
    let module_dir = $"($download_dir)/module"

    curl -L -o $download_path $module.download
    unzip -d $module_dir $download_path
    chmod -R 777 $module_dir
    let module_path = (fd module.json $module_dir)

    mut module = open $module_path
    let module_base_dir = ($module_path | path dirname)

    mut to_remove_components = []

    if not $playlist {
        $to_remove_components = ($to_remove_components | append {pack_type: Playlist, adventure_field: playlists})
    }
    if not $journal {
        $to_remove_components = ($to_remove_components | append {pack_type: JournalEntry, adventure_field: journal})
    }

    # Clean up module
    $module = (rename_deprecated_fields $module)
    $module = (remove_components_from_module $module $module_base_dir $to_remove_components)
    if not ($prefix | is-empty) {
        let new_title = ($module.title | prepend $"($prefix) - " | append " (compressed)" | str join)
        $module = ($module | update title $new_title)
    }

    $module = ($module | reject manifest)
    $module = ($module | reject download)

    # Remove unused packs
    $module = (remove_unused_packs $module $module_base_dir)

    let module_files = (fd -t f . $module_base_dir | lines)
    let used_paths = (extract_used_paths $module $module_base_dir $module_files)

    # Remove files not referenced at all
    for file in $module_files {
        if not $file in $used_paths.abs_decoded_path {
            verbose_remove_files [$file]
        }
    }

    if not ($preview |is-empty) {
        generate_preview_images $used_paths $module_base_dir $module.title $preview $preview_size $quality
    }

    # Compress referenced images
    compress_used_images $used_paths $module_base_dir $quality

    # Save final module
    $module | save -f $module_path

    let $current_dir = (pwd)
    mut output_file = ""
    if ($output_dir |  is-empty) {
        $output_file = ($current_dir | path join $module.title)
    } else {
        $output_file = ($output_dir | path join $module.title)
    }

    if $force {
        rm -rf $output_file
    }
    mv $module_base_dir $output_file
}
