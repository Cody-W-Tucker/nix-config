{ pkgs }:

pkgs.writeShellScriptBin "taskwarrior-rofi" ''
  #!/usr/bin/env bash

# Taskwarrior Rofi integration script

# Configuration with defaults
NOTIFY_COMMAND="''${ROFI_TASKWARRIOR_NOTIFICATION:-notify-send}"
TASKWARRIOR_COMMAND="''${ROFI_TASKWARRIOR_PATH:-task}"
ICON_PATH="''${ROFI_TASKWARRIOR_ICON:-/etc/nixos/modules/icons/taskwarrior.png}"

function notify() {
    case $NOTIFY_COMMAND in
        "rofi")
            rofi -dmenu -l 0 -mesg "''${1}"
            ;;
        "notify-send")
            notify-send -h int:transient:1 -t 3000 "Rofi Taskwarrior" "''${1}" -i "$ICON_PATH"
            ;;
    esac
}

function quick_add() {
    local quickterm=$(rofi -dmenu -l 0 -p 'Quick add' -mesg 'Enter Quick Add syntax for new task')
    if [ -z "$quickterm" ]; then
        exit 0
    else
        if $TASKWARRIOR_COMMAND add "$quickterm"; then
            notify 'Task successfully added'
        else
            notify 'Failed to add task'
        fi
    fi
}

function complete_task() {
    if [ -n "$1" ]; then
        $TASKWARRIOR_COMMAND done "$1" && notify 'Task successfully completed'
    else
        notify 'No task ID provided'
    fi
}

function delete_task() {
    if [ -n "$1" ]; then
        $TASKWARRIOR_COMMAND delete "$1" && notify 'Task successfully deleted'
    else
        notify 'No task ID provided'
    fi
}

function modify_task() {
    if [ -n "$1" ]; then
        local modification=$(rofi -dmenu -l 0 -p 'Modify' -mesg "Enter modification for task $1")
        if [ -n "$modification" ]; then
            $TASKWARRIOR_COMMAND modify "$1" "$modification" && notify 'Task successfully modified'
        fi
    else
        notify 'No task ID provided'
    fi
}

function task_menu() {
    local action=$(printf "Complete task\nDelete task\nModify task" | rofi -dmenu -i -l 3 -p 'Pick an action')
    if [ -z "$action" ]; then
        exit 0
    fi
    
    case "$action" in
        'Complete task')
            complete_task "$1"
            ;;
        'Delete task')
            delete_task "$1"
            ;;
        'Modify task')
            modify_task "$1"
            ;;
    esac
}

function list_tasks() {
    # Sync tasks first
    $TASKWARRIOR_COMMAND sync >/dev/null 2>&1
    
    local filter=""
    [[ -n "$1" ]] && filter="$1"
    
    # Create a formatted output for display
    local task_data=$(mktemp)
    $TASKWARRIOR_COMMAND rc.verbose=nothing "$filter" export rc.json.array=off | jq -r '.[] | "\(.id)|\(.description)|\(.project // "No project")|\(.due // "No due date")|\(.priority // "None")"' > "$task_data"
    
    if [ ! -s "$task_data" ]; then
        notify "No tasks found matching filter '$filter'"
        rm "$task_data"
        return
    fi
    
    # Format task data for display in rofi
    local formatted_tasks=""
    local max_desc_length=50
    
    while IFS='|' read -r id description project due priority; do
        # Truncate description if too long
        if [ ''${#description} -gt $max_desc_length ]; then
            description="''${description:0:$max_desc_length}..."
        fi
        
        # Format due date if it exists
        if [ "$due" != "No due date" ]; then
            due=$(date -d "$due" "+%Y-%m-%d" 2>/dev/null || echo "$due")
        fi
        
        # Add priority indicator
        local priority_indicator=""
        case "$priority" in
            "H") priority_indicator="!" ;;
            "M") priority_indicator="+" ;;
            "L") priority_indicator="-" ;;
            *) priority_indicator=" " ;;
        esac
        
        formatted_tasks+="$id: $priority_indicator [$project] $description ($due)\n"
    done < "$task_data"
    
    rm "$task_data"
    
    # Show rofi menu with formatted tasks
    local selection=$(echo -e "$formatted_tasks" | rofi -dmenu -i -p 'Task' -mesg "Tasks $filter ($(echo -e "$formatted_tasks" | wc -l) total)")
    
    if [ -n "$selection" ]; then
        local task_id=$(echo "$selection" | cut -d':' -f1)
        task_menu "$task_id"
    fi
}

function filter_menu() {
    local filter=$(printf "all\npending\ntoday\noverdue\nweek\npriority:H\nproject:personal\nproject:work\ncustom" | rofi -dmenu -i -l 9 -p 'Filter')
    
    if [ -z "$filter" ]; then
        exit 0
    fi
    
    case "$filter" in
        "all") 
            list_tasks "all" 
            ;;
        "pending") 
            list_tasks "status:pending" 
            ;;
        "today") 
            list_tasks "due:today or scheduled:today" 
            ;;
        "overdue") 
            list_tasks "status:pending due.before:today" 
            ;;
        "week") 
            list_tasks "due.after:now due.before:eow" 
            ;;
        "priority:H") 
            list_tasks "priority:H" 
            ;;
        "project:personal") 
            list_tasks "project:personal" 
            ;;
        "project:work") 
            list_tasks "project:work" 
            ;;
        "custom")
            local custom_filter=$(rofi -dmenu -l 0 -p 'Custom filter' -mesg 'Enter taskwarrior filter')
            if [ -n "$custom_filter" ]; then
                list_tasks "$custom_filter"
            fi
            ;;
    esac
}

function main_menu() {
    local action=$(printf "List tasks\nFilter tasks\nQuick add task\nSync tasks" | rofi -dmenu -i -l 4 -p 'Taskwarrior')
    
    if [ -z "$action" ]; then
        exit 0
    fi
    
    case "$action" in
        "List tasks")
            list_tasks "status:pending"
            ;;
        "Filter tasks")
            filter_menu
            ;;
        "Quick add task")
            quick_add
            ;;
        "Sync tasks")
            $TASKWARRIOR_COMMAND sync && notify "Tasks successfully synced"
            ;;
    esac
}

# Parse command line arguments
if [ "$1" == "quick_add" ]; then
    quick_add
else
    main_menu
fi
''
