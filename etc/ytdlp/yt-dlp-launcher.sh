#!/bin/bash

# YT-DLP Launcher
# Originally created by: Deffcolony
#
# Description:
# This script can download media from YouTube and other sites using yt-dlp.
#
# This script is intended for use on Linux systems.
# Report any issues or bugs on the GitHub repository.
#
# GitHub: https://github.com/deffcolony/ai-toolbox
# Issues: https://github.com/deffcolony/ai-toolbox/issues

# --- Initial Setup and variable definitions ---

# Function to get the script's absolute directory safely
get_script_dir() {
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    cd -P "$( dirname "$SOURCE" )" && pwd
}
SCRIPT_DIR=$(get_script_dir)
cd "$SCRIPT_DIR" || { echo "ERROR: Could not change to script directory."; exit 1; }

# ANSI Escape Codes for Colors
reset='\033[0m'
# Strong Foreground Colors
red_fg_strong='\033[91m'
green_fg_strong='\033[92m'
yellow_fg_strong='\033[93m'
blue_fg_strong='\033[94m'
cyan_fg_strong='\033[96m'
# Normal Background Colors
red_bg='\033[41m'
blue_bg='\033[44m'
yellow_bg='\033[43m'

# Environment Variables (YT-DLP)
ytdlp_path="$SCRIPT_DIR/yt-dlp-downloads"
ytdlp_list="$ytdlp_path/settings/list.txt"
ytdlp_download_url=""
ytdlp_executable="$ytdlp_path/yt-dlp"
ytdlp_audio_path="$ytdlp_path/audio"
ytdlp_video_path="$ytdlp_path/video"
ytdlp_settings_path="$ytdlp_path/settings"

# Define variables to track module status (audio)
audio_modules_path="$ytdlp_path/settings/modules-audio.txt"
audio_sponsorblock_trigger="false"
audio_format_trigger="false"
audio_quality_trigger="false"
audio_acodec_trigger="false"
audio_metadata_trigger="false"
audio_verbose_trigger="false"

# Define variables to track module status (video)
video_modules_path="$ytdlp_path/settings/modules-video.txt"
video_sponsorblock_trigger="false"
video_mergeoutputformat_trigger="false"
video_resolution_trigger="false"
video_acodec_trigger="false"
video_vcodec_trigger="false"
video_metadata_trigger="false"

# Logging variables
log_path="$ytdlp_path/logs.log"
log_invalidinput="[ERROR] Invalid input. Please enter a valid number."
echo_invalidinput="${red_fg_strong}[ERROR] Invalid input. Please enter a valid number.${reset}"

# --- Helper Functions ---

set_title() {
    echo -ne "\033]0;$1\007"
}

log_time() {
    date +"%H:%M:%S"
}

info() {
    echo -e "${blue_bg}[$(log_time)]${reset} ${blue_fg_strong}[INFO]${reset} $1"
}

warn() {
    echo -e "${yellow_bg}[$(log_time)]${reset} ${yellow_fg_strong}[WARN]${reset} $1"
}

error() {
    echo -e "${red_bg}[$(log_time)]${reset} ${red_fg_strong}[ERROR]${reset} $1"
}

pause() {
    read -p "Press Enter to continue..."
}

print_module() {
    # $1: Message, $2: trigger (true/false)
    if [[ "$2" == "true" ]]; then
        echo -e "${green_fg_strong}${1} [Enabled]${reset}"
    else
        echo -e "${red_fg_strong}${1} [Disabled]${reset}"
    fi
}

# --- Architecture Detection ---

detect_arch_url() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  ytdlp_download_url="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux" ;;
        aarch64) ytdlp_download_url="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64" ;;
        armv7l)  ytdlp_download_url="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_armv7l" ;;
        *) error "Unsupported architecture: $arch"; exit 1 ;;
    esac
}

# --- Settings Management Functions ---

save_audio_settings() {
    local cmd=""
    [[ "$audio_sponsorblock_trigger" == "true" ]] && cmd+=" --sponsorblock-remove all"
    [[ "$audio_format_trigger" == "true" ]] && cmd+=" --audio-format $audio_format"
    [[ "$audio_quality_trigger" == "true" ]] && cmd+=" --audio-quality $audio_quality"
    [[ "$audio_acodec_trigger" == "true" ]] && cmd+=" -S acodec:$audio_acodec"
    [[ "$audio_metadata_trigger" == "true" ]] && cmd+=" --embed-metadata --embed-chapters --embed-thumbnail"
    [[ "$audio_verbose_trigger" == "true" ]] && cmd+=" --verbose"

    # Trim leading space if it exists
    audio_start_command="${cmd# }"

    # Save all settings to file
    {
        echo "audio_sponsorblock_trigger='$audio_sponsorblock_trigger'"
        echo "audio_format_trigger='$audio_format_trigger'"
        echo "audio_format='$audio_format'"
        echo "audio_quality_trigger='$audio_quality_trigger'"
        echo "audio_quality='$audio_quality'"
        echo "audio_acodec_trigger='$audio_acodec_trigger'"
        echo "audio_acodec='$audio_acodec'"
        echo "audio_metadata_trigger='$audio_metadata_trigger'"
        echo "audio_verbose_trigger='$audio_verbose_trigger'"
        echo "audio_start_command='$audio_start_command'"
    } > "$audio_modules_path"
}

save_video_settings() {
    local cmd=""
    [[ "$video_sponsorblock_trigger" == "true" ]] && cmd+=" --sponsorblock-remove all"
    [[ "$video_mergeoutputformat_trigger" == "true" ]] && cmd+=" --merge-output-format $mergeoutputformat"
    [[ "$video_resolution_trigger" == "true" ]] && cmd+=" -S res:$video_resolution"
    [[ "$video_acodec_trigger" == "true" ]] && cmd+=" -S acodec:$video_acodec"
    [[ "$video_vcodec_trigger" == "true" ]] && cmd+=" -S vcodec:$video_vcodec"
    [[ "$video_metadata_trigger" == "true" ]] && cmd+=" --embed-metadata --embed-chapters --embed-thumbnail"

    video_start_command="${cmd# }"

    {
        echo "video_sponsorblock_trigger='$video_sponsorblock_trigger'"
        echo "video_mergeoutputformat_trigger='$video_mergeoutputformat_trigger'"
        echo "mergeoutputformat='$mergeoutputformat'"
        echo "video_resolution_trigger='$video_resolution_trigger'"
        echo "video_resolution='$video_resolution'"
        echo "video_acodec_trigger='$video_acodec_trigger'"
        echo "video_acodec='$video_acodec'"
        echo "video_vcodec_trigger='$video_vcodec_trigger'"
        echo "video_vcodec='$video_vcodec'"
        echo "video_metadata_trigger='$video_metadata_trigger'"
        echo "video_start_command='$video_start_command'"
    } > "$video_modules_path"
}

load_settings_file_safe() {
    # Safe key=value parser — no shell execution
    local filepath="$1"
    if [ ! -f "$filepath" ]; then
        touch "$filepath"
        return
    fi
    local line key val
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip blank lines
        [[ -z "$line" ]] && continue
        # Extract key=value, strip surrounding quotes from value
        key="${line%%=*}"
        val="${line#*=}"
        val="${val#\'}" ; val="${val%\'}"
        val="${val#\"}" ; val="${val%\"}"
        # Only allow known variable names (alphanumeric + underscore)
        if [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            printf -v "$key" '%s' "$val"
        fi
    done < "$filepath"
}

load_settings() {
    load_settings_file_safe "$audio_modules_path"
    load_settings_file_safe "$video_modules_path"
}

# --- Core Functionality ---

# Build command args as an array — no eval needed
build_cmd_args() {
    local type="$1"
    cmd_args=()
    if [[ "$type" == "audio" ]]; then
        cmd_args+=("-x")
        [[ "$audio_sponsorblock_trigger" == "true" ]] && cmd_args+=("--sponsorblock-remove" "all")
        [[ "$audio_format_trigger" == "true" && -n "$audio_format" ]] && cmd_args+=("--audio-format" "$audio_format")
        [[ "$audio_quality_trigger" == "true" && -n "$audio_quality" ]] && cmd_args+=("--audio-quality" "$audio_quality")
        [[ "$audio_acodec_trigger" == "true" && -n "$audio_acodec" ]] && cmd_args+=("-S" "acodec:$audio_acodec")
        [[ "$audio_metadata_trigger" == "true" ]] && cmd_args+=("--embed-metadata" "--embed-chapters" "--embed-thumbnail")
        [[ "$audio_verbose_trigger" == "true" ]] && cmd_args+=("--verbose")
    else
        [[ "$video_sponsorblock_trigger" == "true" ]] && cmd_args+=("--sponsorblock-remove" "all")
        [[ "$video_mergeoutputformat_trigger" == "true" && -n "$mergeoutputformat" ]] && cmd_args+=("--merge-output-format" "$mergeoutputformat")
        [[ "$video_resolution_trigger" == "true" && -n "$video_resolution" ]] && cmd_args+=("-S" "res:$video_resolution")
        [[ "$video_acodec_trigger" == "true" && -n "$video_acodec" ]] && cmd_args+=("-S" "acodec:$video_acodec")
        [[ "$video_vcodec_trigger" == "true" && -n "$video_vcodec" ]] && cmd_args+=("-S" "vcodec:$video_vcodec")
        [[ "$video_metadata_trigger" == "true" ]] && cmd_args+=("--embed-metadata" "--embed-chapters" "--embed-thumbnail")
    fi
}

download_media() {
    local type="$1" # "audio" or "video"
    local path_var="ytdlp_${type}_path"
    local output_path="${!path_var}"
    local title_type
    title_type=$(tr '[:lower:]' '[:upper:]' <<< "${type:0:1}")${type:1}

    # Build command args array (safe — no eval)
    build_cmd_args "$type"

    set_title "YT-DLP [DOWNLOAD $title_type]"
    clear

    # Count lines in the list file
    local line_count=0
    if [ -f "$ytdlp_list" ]; then
        line_count=$(wc -l < "$ytdlp_list")
    fi

    # Download from list if not empty
    if (( line_count > 0 )); then
        echo -e "${blue_fg_strong}| > / Home / Download $type / List                             |${reset}"
        echo -e "${blue_fg_strong} ==============================================================${reset}"
        echo -e "${cyan_fg_strong} ______________________________________________________________${reset}"
        echo -e "${cyan_fg_strong}| DEBUG                                                        |${reset}"
        echo "   Preview command: ${cmd_args[*]}"
        echo -e "${cyan_fg_strong} ______________________________________________________________${reset}"
        echo -e "${cyan_fg_strong}| List.txt info                                                |${reset}"
        echo "   Total links queued for download: $line_count"
        echo -e "${cyan_fg_strong} ______________________________________________________________${reset}"
        echo -e "${cyan_fg_strong}| Menu Options:                                                |${reset}"
        echo "   Y. Download all items"
        echo "   N. Cancel"
        echo -e "${cyan_fg_strong} ______________________________________________________________${reset}"
        echo -e "${cyan_fg_strong}|                                                              |${reset}"

        read -p "Download all items from list? [Y/n]: " confirm
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            info "Download canceled. Returning to home."
            pause
            return
        fi

        info "Starting downloads from list..."
        while IFS= read -r url || [ -n "$url" ]; do
            if [[ ! "$url" =~ ^(https?://|www\.) ]]; then
                error "Invalid URL in list: $url. Skipping..."
                continue
            fi
            info "Downloading $type from $url..."
            "$ytdlp_executable" -P "$output_path" "${cmd_args[@]}" -w "$url"
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$title_type] - $url" >> "$log_path"
        done < "$ytdlp_list"

        # Empty the list.txt
        > "$ytdlp_list"
        info "List cleared."

    # Manual input if list is empty
    else
        echo -e "${blue_fg_strong}| > / Home / Download $type / Manual                           |${reset}"
        echo -e "${blue_fg_strong} ==============================================================${reset}"
        echo "   List is empty. Switching to manual input mode."
        echo "   Insert a URL. To know which sites are supported visit the link below:"
        echo "   https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md"
        echo -e "${cyan_fg_strong} ______________________________________________________________${reset}"
        echo -e "${cyan_fg_strong}| Menu Options:                                                |${reset}"
        echo "   0. Cancel"
        echo -e "${cyan_fg_strong} ______________________________________________________________${reset}"
        echo -e "${cyan_fg_strong}|                                                              |${reset}"

        read -p "Insert URL (or 0 to cancel): " url
        if [[ "$url" == "0" || -z "$url" ]]; then
            return
        fi

        if [[ ! "$url" =~ ^(https?://|www\.) ]]; then
            error "Invalid input. URL must start with http://, https://, or www."
            pause
            download_media "$type"
            return
        fi

        info "Downloading $type from $url..."
        "$ytdlp_executable" -P "$output_path" "${cmd_args[@]}" -w "$url"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$title_type] - $url" >> "$log_path"
    fi

    info "${green_fg_strong}$title_type file(s) downloaded successfully.${reset}"
    # Open the output folder when download is finished (xdg-open is the standard)
    if command -v xdg-open &> /dev/null; then
        xdg-open "$output_path"
    fi
    pause
}

# --- Menu Functions ---

home_menu() {
    while true; do
        set_title "YT-DLP [HOME]"
        clear
        echo -e "${blue_fg_strong}/ Home${reset}"
        echo "-------------------------------------------------------------"
        echo "What would you like to do?"
        echo "1. Download audio"
        echo "2. Download video"
        echo "3. Editor"
        echo "4. Update"
        if [ ! -f /.dockerenv ]; then echo '5. Uninstall yt-dlp'; fi
        echo "0. Exit"

        read -p "Choose Your Destiny: " choice

        case "$choice" in
            1) download_media "audio" ;;
            2) download_media "video" ;;
            3) editor_menu ;;
            4) update_ytdlp ;;
            5) if [ ! -f /.dockerenv ]; then uninstall_ytdlp; else error "Uninstall is not available in container mode."; pause; fi ;;
            0) exit_ytdlp ;;
            *) error "$echo_invalidinput"; pause ;;
        esac
    done
}

editor_menu() {
    while true; do
        set_title "YT-DLP [EDITOR]"
        clear
        echo -e "${blue_fg_strong}/ Home / Editor${reset}"
        echo "-------------------------------------------------------------"
        echo "What would you like to do?"
        echo "1. Edit Audio Modules"
        echo "2. Edit Video Modules"
        echo "3. Edit list.txt"
        echo "0. Back to Home"

        read -p "Choose an option: " choice

        case "$choice" in
            1) edit_audio_modules_menu ;;
            2) edit_video_modules_menu ;;
            3) edit_list ;;
            0) return ;;
            *) error "$echo_invalidinput"; pause ;;
        esac
    done
}

edit_audio_modules_menu() {
    while true; do
        set_title "YT-DLP [EDIT AUDIO MODULES]"
        clear
        echo -e "${blue_fg_strong}/ Home / Editor / Edit Audio Modules${reset}"
        echo "-------------------------------------------------------------"
        echo "Choose Audio modules to enable or disable"
        echo -e "Preview: ${cyan_fg_strong}$audio_start_command${reset}"
        echo ""

        print_module "1. SponsorBlock (--sponsorblock-remove all)" "$audio_sponsorblock_trigger"
        print_module "2. Audio Format (--audio-format $audio_format)" "$audio_format_trigger"
        print_module "3. Audio Quality (--audio-quality $audio_quality)" "$audio_quality_trigger"
        print_module "4. Audio Codec (-S acodec:$audio_acodec)" "$audio_acodec_trigger"
        print_module "5. Metadata (--embed-metadata --embed-chapters --embed-thumbnail)" "$audio_metadata_trigger"
        print_module "6. verbose (--verbose)" "$audio_verbose_trigger"

        echo ""
        echo "00. Quick Download Audio"
        echo "0. Back"

        read -p "Choose modules to enable/disable: " choices
        if [[ -z "$choices" ]]; then continue; fi

        for choice in $choices; do
            case "$choice" in
                1) [[ "$audio_sponsorblock_trigger" == "true" ]] && audio_sponsorblock_trigger="false" || audio_sponsorblock_trigger="true" ;;
                2) audio_format_menu ;;
                3) audio_quality_menu ;;
                4) audio_acodec_menu ;;
                5) [[ "$audio_metadata_trigger" == "true" ]] && audio_metadata_trigger="false" || audio_metadata_trigger="true" ;;
                6) [[ "$audio_verbose_trigger" == "true" ]] && audio_verbose_trigger="false" || audio_verbose_trigger="true" ;;
                00) download_media "audio"; return ;;
                0) save_audio_settings; return ;;
                *) error "Invalid choice: $choice" ;;
            esac
        done
        save_audio_settings
    done
}

audio_format_menu() {
    set_title "YT-DLP [SELECT AUDIO FORMAT]"
    clear
    echo -e "${blue_fg_strong}/ Home / Editor / Edit Audio Modules / SELECT AUDIO FORMAT${reset}"
    echo "-------------------------------------------------------------"
    echo "1. mp3"
    echo "2. wav"
    echo "3. flac"
    echo "4. opus"
    echo "5. vorbis"
    echo "6. aac"
    echo "7. m4a"
    echo "8. alac"
    echo -e "${red_fg_strong}00. Disable this module${reset}"
    echo "0. Cancel"

    read -p "Your choice: " choice
    case "$choice" in
        1)  audio_format="mp3";    audio_format_trigger="true" ;;
        2)  audio_format="wav";    audio_format_trigger="true" ;;
        3)  audio_format="flac";   audio_format_trigger="true" ;;
        4)  audio_format="opus";   audio_format_trigger="true" ;;
        5)  audio_format="vorbis"; audio_format_trigger="true" ;;
        6)  audio_format="aac";    audio_format_trigger="true" ;;
        7)  audio_format="m4a";    audio_format_trigger="true" ;;
        8)  audio_format="alac";   audio_format_trigger="true" ;;
        00) audio_format="";       audio_format_trigger="false" ;;
        0)  return ;;
        *)  error "$echo_invalidinput"; pause; audio_format_menu ;;
    esac
}

audio_quality_menu() {
    set_title "YT-DLP [SELECT AUDIO QUALITY]"
    clear
    echo -e "${blue_fg_strong}/ Home / Editor / Edit Audio Modules / SELECT AUDIO QUALITY${reset}"
    echo "-------------------------------------------------------------"
    echo "1.  [0] [Best Quality]"
    echo "2.  1"
    echo "3.  2"
    echo "4.  3"
    echo "5.  4"
    echo "6.  5"
    echo "7.  6"
    echo "8.  7"
    echo "9.  8"
    echo "10. 9"
    echo "11. [10] [Worst Quality]"
    echo "00. Disable this module"
    echo "0.  Cancel"

    read -p "Your choice: " choice
    case "$choice" in
        1)  audio_quality="0";  audio_quality_trigger="true" ;;
        2)  audio_quality="1";  audio_quality_trigger="true" ;;
        3)  audio_quality="2";  audio_quality_trigger="true" ;;
        4)  audio_quality="3";  audio_quality_trigger="true" ;;
        5)  audio_quality="4";  audio_quality_trigger="true" ;;
        6)  audio_quality="5";  audio_quality_trigger="true" ;;
        7)  audio_quality="6";  audio_quality_trigger="true" ;;
        8)  audio_quality="7";  audio_quality_trigger="true" ;;
        9)  audio_quality="8";  audio_quality_trigger="true" ;;
        10) audio_quality="9";  audio_quality_trigger="true" ;;
        11) audio_quality="10"; audio_quality_trigger="true" ;;
        00) audio_quality="";   audio_quality_trigger="false" ;;
        0)  return ;;
        *)  error "$echo_invalidinput"; pause; audio_quality_menu ;;
    esac
}

# Shared codec selection — sets ${prefix}_acodec and ${prefix}_acodec_trigger
_acodec_select() {
    local prefix="$1" title="$2" retry_func="$3"
    local codecs=(mp3 wav flac opus vorbis aac mp4a ac4)

    set_title "YT-DLP [SELECT AUDIO CODEC]"
    clear
    echo -e "${blue_fg_strong}${title}${reset}"
    echo "-------------------------------------------------------------"
    local i
    for i in "${!codecs[@]}"; do
        echo "$(( i + 1 )). ${codecs[$i]}"
    done
    echo -e "${red_fg_strong}00. Disable this module${reset}"
    echo "0. Cancel"

    read -p "Your choice: " choice
    if [[ "$choice" == "0" ]]; then
        return
    elif [[ "$choice" == "00" ]]; then
        printf -v "${prefix}_acodec" '%s' ""
        printf -v "${prefix}_acodec_trigger" '%s' "false"
    elif (( choice >= 1 && choice <= ${#codecs[@]} )) 2>/dev/null; then
        printf -v "${prefix}_acodec" '%s' "${codecs[$(( choice - 1 ))]}"
        printf -v "${prefix}_acodec_trigger" '%s' "true"
    else
        error "$echo_invalidinput"; pause; "$retry_func"
    fi
}

audio_acodec_menu() {
    _acodec_select "audio" "/ Home / Editor / Edit Audio Modules / SELECT AUDIO CODEC" "audio_acodec_menu"
}

edit_video_modules_menu() {
    while true; do
        set_title "YT-DLP [EDIT VIDEO MODULES]"
        clear
        echo -e "${blue_fg_strong}/ Home / Editor / Edit Video Modules${reset}"
        echo "-------------------------------------------------------------"
        echo "Choose Video modules to enable or disable"
        echo -e "Preview: ${cyan_fg_strong}$video_start_command${reset}"
        echo ""

        print_module "1. Sponsor Block (--sponsorblock-remove all)" "$video_sponsorblock_trigger"
        print_module "2. Merge Output Format (--merge-output-format $mergeoutputformat)" "$video_mergeoutputformat_trigger"
        print_module "3. Resolution (-S res:$video_resolution)" "$video_resolution_trigger"
        print_module "4. Audio Codec (-S acodec:$video_acodec)" "$video_acodec_trigger"
        print_module "5. Video Codec (-S vcodec:$video_vcodec)" "$video_vcodec_trigger"
        print_module "6. Metadata (--embed-metadata --embed-chapters --embed-thumbnail)" "$video_metadata_trigger"

        echo ""
        echo "00. Quick Download Video"
        echo "0. Back"

        read -p "Choose modules to enable/disable: " choices
        if [[ -z "$choices" ]]; then continue; fi

        for choice in $choices; do
            case "$choice" in
                1) [[ "$video_sponsorblock_trigger" == "true" ]] && video_sponsorblock_trigger="false" || video_sponsorblock_trigger="true" ;;
                2) video_mergeoutputformat_menu ;;
                3) video_resolution_menu ;;
                4) video_acodec_menu ;;
                5) video_vcodec_menu ;;
                6) [[ "$video_metadata_trigger" == "true" ]] && video_metadata_trigger="false" || video_metadata_trigger="true" ;;
                00) download_media "video"; return ;;
                0) save_video_settings; return ;;
                *) error "Invalid choice: $choice" ;;
            esac
        done
        save_video_settings
    done
}

video_mergeoutputformat_menu() {
    set_title "YT-DLP [SELECT MERGE OUTPUT FORMAT]"
    clear
    echo -e "${blue_fg_strong}/ Home / Editor / Edit Video Modules / SELECT MERGE OUTPUT FORMAT${reset}"
    echo "-------------------------------------------------------------"
    echo "1. mp4"
    echo "2. flv"
    echo "3. mkv"
    echo "4. mov"
    echo "5. avi"
    echo "6. webm"
    echo -e "${red_fg_strong}00. Disable this module${reset}"
    echo "0. Cancel"

    read -p "Your choice: " choice
    case "$choice" in
        1)  mergeoutputformat="mp4";  video_mergeoutputformat_trigger="true" ;;
        2)  mergeoutputformat="flv";  video_mergeoutputformat_trigger="true" ;;
        3)  mergeoutputformat="mkv";  video_mergeoutputformat_trigger="true" ;;
        4)  mergeoutputformat="mov";  video_mergeoutputformat_trigger="true" ;;
        5)  mergeoutputformat="avi";  video_mergeoutputformat_trigger="true" ;;
        6)  mergeoutputformat="webm"; video_mergeoutputformat_trigger="true" ;;
        00) mergeoutputformat="";     video_mergeoutputformat_trigger="false" ;;
        0)  return ;;
        *)  error "$echo_invalidinput"; pause; video_mergeoutputformat_menu ;;
    esac
}

video_resolution_menu() {
    set_title "YT-DLP [SELECT VIDEO RESOLUTION]"
    clear
    echo -e "${blue_fg_strong}/ Home / Editor / Edit Video Modules / SELECT VIDEO RESOLUTION${reset}"
    echo "-------------------------------------------------------------"
    echo "1. 4320p 8K"
    echo "2. 2160p 4K"
    echo "3. 1440p HD"
    echo "4. 1080p HD"
    echo "5. 720p"
    echo "6. 480p"
    echo "7. 360p"
    echo "8. 240p"
    echo "9. 144p"
    echo -e "${red_fg_strong}00. Disable this module${reset}"
    echo "0. Cancel"

    read -p "Your choice: " choice
    case "$choice" in
        1)  video_resolution="4320"; video_resolution_trigger="true" ;;
        2)  video_resolution="2160"; video_resolution_trigger="true" ;;
        3)  video_resolution="1440"; video_resolution_trigger="true" ;;
        4)  video_resolution="1080"; video_resolution_trigger="true" ;;
        5)  video_resolution="720";  video_resolution_trigger="true" ;;
        6)  video_resolution="480";  video_resolution_trigger="true" ;;
        7)  video_resolution="360";  video_resolution_trigger="true" ;;
        8)  video_resolution="240";  video_resolution_trigger="true" ;;
        9)  video_resolution="144";  video_resolution_trigger="true" ;;
        00) video_resolution="";     video_resolution_trigger="false" ;;
        0)  return ;;
        *)  error "$echo_invalidinput"; pause; video_resolution_menu ;;
    esac
}

video_acodec_menu() {
    _acodec_select "video" "/ Home / Editor / Edit Video Modules / SELECT AUDIO CODEC" "video_acodec_menu"
}

video_vcodec_menu() {
    set_title "YT-DLP [SELECT VIDEO CODEC]"
    clear
    echo -e "${blue_fg_strong}/ Home / Editor / Edit Video Modules / SELECT VIDEO CODEC${reset}"
    echo "-------------------------------------------------------------"
    echo "1. h264"
    echo "2. h265"
    echo "3. h263"
    echo "4. av01"
    echo "5. vp9.2"
    echo "6. vp9"
    echo "7. vp8"
    echo "8. theora"
    echo -e "${red_fg_strong}00. Disable this module${reset}"
    echo "0. Cancel"

    read -p "Your choice: " choice
    case "$choice" in
        1)  video_vcodec="h264";   video_vcodec_trigger="true" ;;
        2)  video_vcodec="h265";   video_vcodec_trigger="true" ;;
        3)  video_vcodec="h263";   video_vcodec_trigger="true" ;;
        4)  video_vcodec="av01";   video_vcodec_trigger="true" ;;
        5)  video_vcodec="vp9.2";  video_vcodec_trigger="true" ;;
        6)  video_vcodec="vp9";    video_vcodec_trigger="true" ;;
        7)  video_vcodec="vp8";    video_vcodec_trigger="true" ;;
        8)  video_vcodec="theora"; video_vcodec_trigger="true" ;;
        00) video_vcodec="";       video_vcodec_trigger="false" ;;
        0)  return ;;
        *)  error "$echo_invalidinput"; pause; video_vcodec_menu ;;
    esac
}

edit_list() {
    set_title "YT-DLP [EDIT LIST]"
    clear
    echo -e "${cyan_fg_strong}Please add links to the list then save and close the editor to continue.${reset}"
    # Use standard EDITOR variable, fallback to nano/vi
    if [ -n "$EDITOR" ]; then
        "$EDITOR" "$ytdlp_list"
    elif command -v nano &> /dev/null; then
        nano "$ytdlp_list"
    elif command -v vi &> /dev/null; then
        vi "$ytdlp_list"
    else
        error "No text editor found (nano, vi, or \$EDITOR). Please edit '$ytdlp_list' manually."
        pause
    fi
}

# --- System and Maintenance Functions ---

update_ytdlp() {
    info "Checking for yt-dlp update..."
    if [ -f "$ytdlp_executable" ]; then
        "$ytdlp_executable" -U
    else
        warn "yt-dlp not found. Attempting to install."
        install_ytdlp
    fi
    pause
}

uninstall_ytdlp() {
    set_title "YT-DLP [UNINSTALL YT-DLP]"
    clear
    echo -e "${red_bg}╔════ DANGER ZONE ══════════════════════════════════════╗${reset}"
    echo -e "${red_bg}║ WARNING: This will delete all data of yt-dlp-launcher. ║${reset}"
    echo -e "${red_bg}╚════════════════════════════════════════════════════════╝${reset}"
    echo ""
    read -p "Are you sure you want to proceed? [y/N]: " confirmation
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        info "Removing the YT-DLP directory..."
        rm -rf "$ytdlp_path"
        info "${green_fg_strong}YT-DLP has been uninstalled successfully.${reset}"
        pause
    else
        info "Uninstall canceled."
        pause
    fi
}

exit_ytdlp() {
    set_title "YT-DLP [EXIT]"
    clear
    read -p "Are you sure you want to exit yt-dlp-launcher? [Y/n]: " choice
    if [[ -z "$choice" || "$choice" =~ ^[Yy]$ ]]; then
        exit 0
    fi
}

check_dependencies() {
    info "Checking for required dependencies..."
    declare -A deps=( ["curl"]="curl" ["ffmpeg"]="ffmpeg" ["atomicparsley"]="atomicparsley" )
    local missing_deps=()
    for cmd in "${!deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("${deps[$cmd]}")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        warn "The following dependencies are missing: ${missing_deps[*]}"
        local pm_update pm_install
        if command -v apt-get &> /dev/null; then
            pm_update="sudo apt-get update -qq"
            pm_install="sudo apt-get install -y"
        elif command -v dnf &> /dev/null; then
            pm_update=""
            pm_install="sudo dnf install -y"
        elif command -v pacman &> /dev/null; then
            pm_update=""
            pm_install="sudo pacman -S --noconfirm"
        else
            error "Could not detect a supported package manager (apt, dnf, pacman)."
            error "Please install the following packages manually: ${missing_deps[*]}"
            exit 1
        fi
        info "Attempting to install missing dependencies..."
        [[ -n "$pm_update" ]] && $pm_update
        if ! $pm_install "${missing_deps[@]}"; then
            error "Failed to install dependencies. Please install them manually."
            exit 1
        fi
    else
        info "All dependencies are satisfied."
    fi
}

install_ytdlp() {
    info "Installing yt-dlp..."
    if curl -L "$ytdlp_download_url" -o "$ytdlp_executable"; then
        chmod +x "$ytdlp_executable"
        info "${green_fg_strong}yt-dlp installed successfully.${reset}"
    else
        error "Failed to download yt-dlp. Please check your internet connection."
        exit 1
    fi
}

create_shortcut() {
    local desktop_path="$HOME/Desktop"
    if [ ! -d "$desktop_path" ]; then
        # Check common alternative locations
        if [ -d "$HOME/desktop" ]; then
            desktop_path="$HOME/desktop"
        else
            warn "Desktop directory not found. Skipping shortcut creation."
            return
        fi
    fi

    read -p "Do you want to create a shortcut on the desktop? [Y/n] " create
    if [[ -z "$create" || "$create" =~ ^[Yy]$ ]]; then
        info "Creating shortcut..."
        cat > "$desktop_path/yt-dlp-launcher.desktop" << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=YT-DLP Launcher
Comment=A launcher for yt-dlp
Exec=bash "$SCRIPT_DIR/$(basename "$0")"
Icon=$SCRIPT_DIR/logo.ico
Path=$SCRIPT_DIR
Terminal=true
EOL
        chmod +x "$desktop_path/yt-dlp-launcher.desktop"
        info "${green_fg_strong}Shortcut created on the desktop.${reset}"
    fi
}

# --- Main Execution Logic ---

main() {
    set_title "YT-DLP [STARTUP CHECK]"

    # Detect architecture and set download URL
    detect_arch_url

    # Check for spaces or special characters in the script path
    local bad_chars='[[:space:]!#$%&()*+,;<=>?@\[\]^`{|}~]'
    if [[ "$SCRIPT_DIR" =~ $bad_chars ]]; then
        error "Path cannot contain spaces or special characters: [!#\$%&'()*+,;<=>?@[]^\`{|}~]"
        error "Path: ${red_bg}$SCRIPT_DIR${reset}"
        pause
        exit 1
    fi

    # Create necessary directories and files
    mkdir -p "$ytdlp_audio_path" "$ytdlp_video_path" "$ytdlp_settings_path"
    touch "$ytdlp_list" "$audio_modules_path" "$video_modules_path"

    # Load settings from files
    load_settings

    # Check for system dependencies like curl, ffmpeg
    if [ ! -f /.dockerenv ]; then
        check_dependencies
    fi

    # Check if yt-dlp exists, if not, download it
    if [ ! -f "$ytdlp_executable" ]; then
        install_ytdlp
        create_shortcut
        info "Initial setup complete. Please restart the launcher."
        pause
        exec bash "$0" "$@" # Restart script
    fi

    home_menu
}

# Run the main function
main
