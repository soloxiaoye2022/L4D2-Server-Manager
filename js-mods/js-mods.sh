#!/bin/bash

#获取脚本当前路径
DEFAULT_SH=$(cd $(dirname $0) && pwd)
# 指定文件夹路径
folder_path=${DEFAULT_SH}/JS-MODS
#保存已装插件的名字文件
plugins_name=${DEFAULT_SH}/plugins.txt
#保存进度条文件
progress_name=${DEFAULT_SH}/progress.txt

# 初始化一个空数组来存储用户选择的文件夹名字
selected_folders=()

trap 'onCtrlC' INT
function onCtrlC () {
        #捕获CTRL+C，当脚本被ctrl+c的形式终止时同时终止程序的后台进程
        kill -9 ${do_sth_pid} ${progress_pid}
        echo
        echo 'Ctrl+C is captured'
        exit 1
}

do_sthi() {
        #运行的主程序
        cp -rf "$folder_path/$folder_name/left4dead2" "${DEFAULT_SH}"		#使用cp命令来安装插件
}

do_sthii() {
        #运行的主程序
        for subfold in "${subfolde[@]}"; do
				#echo rm -r "${DEFAULT_SH}/$subfold"		#检测rm命令的对错
				rm -r "${DEFAULT_SH}/$subfold"			#使用rm命令来删除服务端内的插件文件
		done
}

progress() {
        #进度程序
        local main_pid=$1
        local length=20
        local ratio=1
        while [ "$(ps -p ${main_pid} | wc -l)" -ne "1" ] ; do
                mark='>'
                progress_bar=
                for i in $(seq 1 "${length}"); do
                        if [ "$i" -gt "${ratio}" ] ; then
                                mark='-'
                        fi
                        progress_bar="${progress_bar}${mark}"
                done
                printf "操作中: ${progress_bar}\r"
				printf "操作中: ${progress_bar}\n" > "$progress_name"
                ratio=$((ratio+1))
                #ratio=`expr ${ratio} + 1`
                if [ "${ratio}" -gt "${length}" ] ; then
                        ratio=1
                fi
                sleep 0.1
        done
}

progress_runi() {
do_sthi &
do_sth_pid=$(jobs -p | tail -1)
progress "${do_sth_pid}" &
progress_pid=$(jobs -p | tail -1)
wait "${do_sth_pid}"
cat "$progress_name"
}

progress_runii() {
do_sthii &
do_sth_pid=$(jobs -p | tail -1)
progress "${do_sth_pid}" &
progress_pid=$(jobs -p | tail -1)
wait "${do_sth_pid}"
cat "$progress_name"
}

# 函数来加载数组
load_arrayi() {
if [ -s "$plugins_name" ]; then
    mapfile -t selected_folder < "$plugins_name"
else
	echo -e "\e[31m未安装插件，请安装插件后再使用此选项\e[0m"
	exit
fi
}

load_arrayii() {
if [ -s "$plugins_name" ]; then
    mapfile -t selected_folder < "$plugins_name"
fi
}

get_namei() {
load_arrayii

# 使用ls命令列出指定文件夹下的文件夹，-d选项用于只显示目录而不显示其内容
subfolders=($(ls -d "$folder_path"/*/))

count=1
for subfolder in "${subfolders[@]}"; do
    folder_name=$(basename "$subfolder")
    # 检查是否在排除的数组中
    if [[ " ${selected_folder[*]} " == *" $folder_name "* ]]; then
        continue  # 跳过这个文件夹
    fi

    echo -e "\e[92m$count\e[0m.\e[34m$folder_name\e[0m"
	subfolde+=($folder_name) #创建数组
    ((count++))
done
}

get_nameii() {
load_arrayi
# 遍历数组并为每个文件夹分配一个数字
count=1
for subfolder in "${selected_folder[@]}"; do
    folder_name=$(basename "$subfolder")
	echo -e "\e[92m$count\e[0m.\e[34m$folder_name\e[0m"
    ((count++))
done

}

plugins_install() {
# 询问用户输入数字，以分号分隔
echo -e "\e[36m请输入需要安装的插件数字，用分号\e[0m\e[41m（;）\e[0m\e[36m隔开\e[0m\e[41m（注意；数字如果错误一个则需要全部重新输入）\e[0m"
read user_input
IFS=";" read -ra input_numbers <<< "$user_input"

# 遍历用户输入的数字
for number in "${input_numbers[@]}"; do
    if [[ $number =~ ^[0-9]+$ ]]; then
        index=$((number - 1))
		if [[ $number -ge 1 && $number -le ${#subfolde[@]} ]]; then
			selected_folders+=("${subfolde[number-1]}")
		else
			echo -e "\e[31m无效的数字\e[0m：\e[36m$number\e[0m，\e[31m请重新输入\e[0m"
			#plugins_install
		fi
		
        if ((index >= 0 && index < ${#subfolde[@]})); then
            selected_subfolder="${subfolde[index]}"
            folder_name=$(basename "$selected_subfolder")
			test_name+=($(basename "$folder_name"))							#创建数组
            #echo cp -rf "$folder_path/$folder_name/left4dead2" "${DEFAULT_SH}" 		#测试cp命令内容
			echo -e "\e[46;34m正在安装插件\e[0m：\e[36m$folder_name\e[0m"
			progress_runi
			echo -e "\e[46;34m安装完成\e[0m"

        else
            echo -e "\e[31m无效的数字\e[0m：\e[36m$number\e[0m，\e[31m请重新输入\e[0m"
			plugins_install
        fi
    else
        echo -e "\e[31m无效的输入\e[0m：\e[36m$number\e[0m，\e[31m请重新输入\e[0m"
		plugins_install
    fi
done

# 保存数组到文件，以便插件读取数组
printf "%s\n" "${test_name[@]}" >> "$plugins_name"


}

plugins_unload() {
# 询问用户输入数字，以分号分隔
echo -e "\e[36m请输入需要卸载的插件数字，用分号\e[0m\e[41m（;）\e[0m\e[36m隔开\e[0m\e[41m（注意；数字如果错误一个则需要全部重新输入）\e[0m"
read user_input
IFS=";" read -ra input_numbers <<< "$user_input"

for number in "${input_numbers[@]}"; do
    if [[ $number =~ ^[0-9]+$ ]]; then
        index=$((number - 1))
        if ((index >= 0 && index < ${#selected_folder[@]})); then
            selected_subfolder="${selected_folder[index]}"
            folder_name=$(basename "$selected_subfolder")
			test_name+=($(basename "$folder_name"))					#创建数组
			subfolde=($(find "$folder_path/$folder_name" -type f | sed "s|^$folder_path/$folder_name/||"))		#寻找"folder_name"函数所选插件名下的所有文件，并赋值于新数组
			echo -e "\e[46;34m正在卸载插件\e[0m：\e[36m$folder_name\e[0m"
			progress_runii
			echo -e "\e[46;34m卸载完成\e[0m"
        else
            echo -e "\e[31m无效的数字\e[0m：\e[36m$number\e[0m，\e[31m请重新输入\e[0m"
			plugins_unload
        fi
    else
        echo -e "\e[31m无效的输入\e[0m：\e[36m$number\e[0m"
		plugins_unload
    fi
done

for name in "${test_name[@]}"; do
    # 使用grep来过滤出不需要删除的文件名
    grep -v "$name" "$plugins_name" > temp.txt
    mv temp.txt "$plugins_name"
done
}

while true; do
    if [ "$run_sp" == "true" ]; then
        # 如果运行了自定义函数 "sp_runi" 或 "sp_runii"，则退出循循环
        break
    fi
    
    echo -e "\e[33m请选择要执行的操作:\e[0m"
    echo -e "\e[92m1\e[0m.\e[34m安装插件\e[0m"
    echo -e "\e[92m2\e[0m.\e[34m卸载插件\e[0m"
    echo -e "\e[92m3\e[0m.\e[34m退出\e[0m"
    read -p "您的选择是: " choice
    
    case $choice in
        1)
            get_namei
			plugins_install
            run_sp=true  # 设置标志变量为 true
            ;;
        2)
            get_nameii
			plugins_unload
            run_sp=true  # 设置标志变量为 true
            ;;
        3)
            exit 0
            ;;
        *)
            echo -e "\e[31m 无效选项，请重新输入 \e[0m"
            ;;
    esac
done