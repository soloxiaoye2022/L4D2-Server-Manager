#!/bin/bash

check_dir() {
  # 如果目录路径为空，返回1
  if [ -z "$1" ]; then
    return 1
  fi
  # 如果目录路径不以/开头，返回2
  if [ "${1:0:1}" != "/" ]; then
    return 2
  fi
  # 如果目录路径不存在，返回3
  if [ ! -d "$1" ]; then
    return 3
  fi
  # 如果目录路径有效，返回0
  return 0
}

#获取脚本当前路径
DEFAULT_SH=$(cd $(dirname $0) && pwd)
#获取插件平台文件路径
DEFAULT_MENUII=$(dirname "$DEFAULT_SH")
#获取当前输入命令的路径
DEFAULT_CMD=$(pwd)

# 定义函数
sp_namei() {
			# 创建一个空数组来存储文件名
			file_list=()

			# 循环，让用户输入文件名
			while true; do
				echo -e "\e[36m 请输入插件文件名 \e[0m\e[41m (必须包含后缀.sp，并且输入quit或exit以结束输入) \e[0m："
				read filename
				if [ "$filename" == "exit" ]; then
					break
				elif [ "$filename" == "quit" ]; then
					break
				fi

				# 检查文件是否存在
				if [ -e "${DEFAULT_SH}/$filename" ]; then
					file_list+=("$filename")
				else
					echo "文件 $filename 不存在于目标文件夹中"
				fi
			done
}

sp_nameii() {
			# 创建一个空数组来存储文件名
			file_list=()

			# 循环，让用户输入文件名
			while true; do
				echo -e "\e[36m 请输入插件文件名 \e[0m\e[41m (必须包含后缀.sp，并且输入quit或exit以结束输入) \e[0m："
				read filename
				if [ "$filename" == "exit" ]; then
					break
				elif [ "$filename" == "quit" ]; then
					break
				fi

				# 检查文件是否存在
				if [ -e "${DEFAULT_SP}/$filename" ]; then
					file_list+=("$filename")
				else
					echo "文件 $filename 不存在于目标文件夹中"
				fi
			done
}

sp_menu() {
# 定义一个变量，用来存储用户输入的目录路径
			dir=""
			# 定义一个循环，用来让用户输入目录路径，直到输入有效为止
			while true; do
				# 提示用户输入目录路径，并读取用户的输入
				echo -e "\e[36m 请输入插件路径 \e[0m\e[41m (不是插件文件的路径，而是插件目录路径) \e[0m："
				read dir
				# 调用check_dir函数，检查用户输入的目录路径是否有效，并获取返回值
				check_dir "$dir"
				result=$?
				# 根据返回值，判断是否需要继续循环或者退出循环
				case $result in
					# 如果返回值为0，表示目录路径有效，给参数“DEFAULT_SP”赋值为用户输入的目录路径，并退出循环
					0) DEFAULT_SP="$dir"
					break;;
					# 如果返回值为1，表示目录路径为空，提示用户重新输入，并继续循环
					1) echo -e "\e[31m 您没有输入任何内容，请重新输入。 \e[0m";;
					# 如果返回值为2，表示目录路径不以/开头，提示用户重新输入，并继续循环
					2) echo -e "\e[31m 您输入的不是一个绝对路径，请重新输入。 \e[0m";;
					# 如果返回值为3，表示目录路径不存在，提示用户重新输入，并继续循环
					3) echo -e "\e[31m 您输入的插件路径不存在，请重新输入。 \e[0m";;
					# 其他情况，不应该发生，但为了安全起见，提示用户重新输入，并继续循环
					*) echo -e "\e[31m 发生了未知的错误，请重新输入。 \e[0m";;
				esac
			done
}

sp_runi() {
# 遍历文件名数组并获取前缀
			for filename in "${file_list[@]}"; do
				command="./spcomp64 "$filename""
				echo -e "\e[36m开始编码文件\e[0m\e[41m$filename\e[0m\e[36m，以下是编码信息\e[0m"
				$command
				# 使用basename命令获取文件名（不包含路径）
				base_filename=$(basename "$filename")

				# 使用参数扩展来提取前缀
				prefix="${base_filename%%.*}"

				if [ -e "${DEFAULT_CMD}/$prefix.smx" ]; then
					while true; do
					echo -e "\e[36m 是否替换掉当前服务端文件内的插件文件？ \e[0m\e[41m (请输入y或n) \e[0m"
					read response
						if [ "$response" == "y" ]; then
							echo -e "\e[46;34m 正在替换当前服务端文件的原本$prefix.smx插件文件 \e[0m"
							mv -f "${DEFAULT_CMD}/$prefix.smx" "${DEFAULT_MENUII}/plugins"
							# echo mv -f "${DEFAULT_CMD}/$prefix.smx" "${DEFAULT_MENUII}/plugins"
							echo -e "\e[46;34m 替换完成 \e[0m"
							break  # 继续下一个文件名
						elif [ "$response" == "n" ]; then
							echo -e "\e[46;34m 编码完毕，插件$prefix.smx文件在当前输入命令的目录下 \e[0m"
							break  # 继续下一个文件名
						else
							echo -e "\e[31m 输入不对，请重新输入 \e[0m"
						fi
					done
				else
					echo -e "\e[31m 编码失败，请查看编码信息后，修改sp文件报错内容 \e[0m"
					while true; do
					echo -e "\e[36m 是否编码下一个插件文件？ \e[0m\e[41m (请输入y或n，n为退出脚本) \e[0m"
					read responsei
						if [ "$responsei" == "y" ]; then
							break  # 继续下一个文件名
						elif [ "$responsei" == "n" ]; then
							#退出脚本
							exit  # 继续下一个文件名
						else
							echo -e "\e[31m 输入不对，请重新输入 \e[0m"
						fi
					done
				fi	
	
			done
}

sp_runii() {
			#获取插件平台文件路径
			DEFAULT_MENUI=$(dirname "$DEFAULT_SP")

			# 遍历文件名数组并获取前缀
			for filename in "${file_list[@]}"; do
				command=""${DEFAULT_SP}/spcomp64" "${DEFAULT_SP}/$filename""
				echo -e "\e[36m开始编码文件\e[0m\e[41m$filename\e[0m\e[36m，以下是编码信息\e[0m"
				$command
				# 使用basename命令获取文件名（不包含路径）
				base_filename=$(basename "$filename")

				# 使用参数扩展来提取前缀
				prefix="${base_filename%%.*}"

				if [ -e "${DEFAULT_CMD}/$prefix.smx" ]; then
					while true; do
					echo -e "\e[36m 是否替换掉当前服务端文件内的插件文件？ \e[0m\e[41m (请输入y或n) \e[0m"
					read response
						if [ "$response" == "y" ]; then
							echo -e "\e[46;34m 正在替换当前服务端文件的原本$prefix.smx插件文件 \e[0m"
							mv -f "${DEFAULT_CMD}/$prefix.smx" "${DEFAULT_MENUI}/plugins"
							echo mv -f "${DEFAULT_CMD}/$prefix.smx" "${DEFAULT_MENUI}/plugins"
							echo -e "\e[46;34m 替换完成 \e[0m"
							break  # 继续下一个文件名
						elif [ "$response" == "n" ]; then
							echo -e "\e[46;34m 编码完毕，插件$prefix.smx文件在当前输入命令的目录下 \e[0m"
							break  # 继续下一个文件名
						else
							echo -e "\e[31m 输入不对，请重新输入 \e[0m"
						fi
					done
				else
					echo -e "\e[31m 编码失败，请查看编码信息后，修改sp文件报错内容 \e[0m"
					while true; do
					echo -e "\e[36m 是否编码下一个插件文件？ \e[0m\e[41m (请输入y或n，n为退出脚本) \e[0m"
					read responsei
						if [ "$responsei" == "y" ]; then
							break  # 继续下一个文件名
						elif [ "$responsei" == "n" ]; then
							#退出脚本
							exit
						else
							echo -e "\e[31m 输入不对，请重新输入 \e[0m"
						fi
					done
				fi	
	
			done
}

run_sp=false  # 设置标志变量，初始值为 false

while true; do
    if [ "$run_sp" == "true" ]; then
        # 如果运行了自定义函数 "sp_runi" 或 "sp_runii"，则退出循循环
        break
    fi
    
    echo -e "\e[33m请选择要执行的操作:\e[0m"
    echo -e "\e[92m1\e[0m.\e[34m只输入文件名形式\e[0m"
    echo -e "\e[92m2\e[0m.\e[34m输入路径和文件名形式\e[0m"
    echo -e "\e[92m3\e[0m.\e[34m退出\e[0m"
    read -p "您的选择是: " choice
    
    case $choice in
        1)
            sp_namei
            sp_runi
            run_sp=true  # 设置标志变量为 true
            ;;
        2)
            sp_menu
            sp_nameii
            sp_runii
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