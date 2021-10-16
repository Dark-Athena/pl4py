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

## 安装步骤

#### 第一步
在数据库操作系统上安装python程序，并安装flask包，建议py3，py2没有测试  
```bat
pip install flask
```

#### 第二步
在数据库所在的操作系统上建立一个文件夹，此文件夹会保存你在数据库中创建的包含python函数的文件  
例如：
```bat
mkdir F:\oracle\PY_FILE
```

#### 第三步
在数据库中创建一个目录 ，名称为 “PY_FILE” ，指向操作系统中，上一步你创建的文件夹
```sql
create or replace directory PY_FILE as 'F:\oracle\PY_FILE'
```

#### 第四步
使用数据库sys账号对你想要安装本程序的用户进行授权，
```sql
grant select on dba_directories to {username} with grant option;
```

#### 第五步
登录你要安装本程序的数据库账号，依次执行以下脚本
- PL4PY_FUNC_LIST.sql
- PL4PY_FUNC_LIST_TRI.trg
- PL4PY.pck
- pl4py_func_list_v.sql

## 使用举例

#### 一、启动服务
```sql
begin
  PL4PY.start_service;
end;
```
#### 二、创建（或更新）函数
```sql
BEGIN
  PL4PY.create_func(i_func_name => 'sample_f.py',
                    i_contents  => q'{def sample_f(num):
    return float(num)*float(num)
}');
END;
```

#### 三、使用函数
```sql
select  pl4py.call_func_Eval('sample_f.py', '8') r from dual;
>64
```

#### 四、删除函数
```sql
BEGIN
  PL4PY.drop_func(i_func_name => 'sample_f.py');
END;
```

#### 五、停止服务
```sql
begin
  PL4PY.stop_service;
end;
```

memo:服务被设计成长期运行的schedule_job，函数动态切换，因此除非要完全停止或者检查问题，一般不需要执行 PL4PY.stop_service
