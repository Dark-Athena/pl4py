# pl4py
在oracle数据库中使用自定义python函数（不是21c版本中的OML4PY）  
这是开发中的版本，请勿用于生产环境  
请确保oracle数据库版本至少为10g  
数据库操作系统上需要安装python  
为了避免一些不可控的情况，需要在程序中提前手工指定python主程序的全路径  
目前只在windows环境中测试通过  

原理：
使用schedule_job启动python的flask服务，
通过utl_file包将用户自定义函数生成文件保存到操作系统
使用utl_http包发送请求到flask，传入函数名称及参数数据
flask动态从文件加载python函数，并将参数数据传入函数，获得返回值
此时，plsql中可获得python函数返回的结果
