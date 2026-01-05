Steam 创意工坊下载工具
用法: bash steamwork_downloader.sh [选项] <文件ID列表>  
选项:  
  -a    自动模式 (直接下载)  
  -q    仅查询模式 (不下载)  
  -c NUM 设置并发数 (默认: 5)  
  -d    启用调试模式  
示例:  
  -a -c 10 123 456 789     自动下载3个文件，10并发  
  -q 123456                仅查询文件信息  
  未完成，待完善 来源https://partner.steamgames.com/doc/webapi/ISteamRemoteStorage#GetPublishedFileDetails