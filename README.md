# pl4py
项目地址 https://github.com/Dark-Athena/pl4py

this pkg provide a common way to call python function in oracle plsql .   
after install ,you can create python function and use it without logging db'OS  .   
WARNING: This is a development pkg. Do not use it in a production deployment  .   

 Requirements:
 - Operating System :windows   (2021-11-01 add linux(/bin/sh))
 - Python Version:python 3 at least   
 - Oracle Database Release : 10g at least  

使用本程序，你可以在oracle数据库中使用自定义python函数
（不是21c版本中的OML4PY [【ORACLE】在ORACLE数据库中启用机器学习功能（OML）以支持PYTHON脚本的运行](https://www.darkathena.top/archives/oml4py-server-setup) ）  
安装此组件后，你可以在数据库中创建并且使用自定义函数，并自由开启关闭此服务，整个过程无需登录数据库的操作系统
这是开发中的版本，请勿用于生产环境  
请确保oracle数据库版本至少为10g  
数据库操作系统上需要安装python  
为了避免一些不可控的情况，需要在程序中提前手工指定python主程序的全路径  
目前只在windows环境中测试通过  (2011-11-01增加了linux环境的支持)

#### 原理：  
使用schedule_job启动python的flask服务(主要为避免登录到操作系统进行操作，能让开发人员实现纯数据库内操作)  
通过utl_file包将用户自定义函数生成py文件保存到操作系统  
使用utl_http包发送请求到flask，传入函数名称及参数数据  
flask动态从文件加载python函数，并将参数数据传入函数，获得返回值  
此时，plsql中可获得python函数返回的结果  

## 安装步骤

#### 第一步
在数据库操作系统上安装python程序，并安装flask包，建议py3，py2没有测试  
```bat
pip3 install flask
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

64
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


## 更复杂的函数例子
1. 基于原始数据计算一个时间和速度相关性的模型，然后输入时间，返回速度
```sql
BEGIN
  PL4PY.create_func(i_func_name => 'forecast_speed.py',
                    i_contents  => q'{import numpy
from sklearn.metrics import r2_score
import matplotlib.pyplot as plt
def forecast_speed(hour):
    x = [1,2,3,5,6,7,8,9,10,12,13,14,15,16,18,19,21,22]
    y = [100,90,80,60,60,55,60,65,70,70,75,76,78,79,90,99,99,100]
    mymodel = numpy.poly1d(numpy.polyfit(x, y, 3))
    myline = numpy.linspace(1, 23, 100)
    speed = mymodel(float(hour))
    return {'speed':speed}
}');
END;

select pl4py.call_func_Eval(i_func_name =>'forecast_speed.py', i_data=>'11') r from dual

{"speed": 65.03276500414789}
```

2. 传入一个sql，获得sql中的所有表或视图名称
将 https://github.com/Dark-Athena/list_table_sql-py 
中的所有文件下载到安装步骤第二步中的文件夹，比如 “F:\oracle\PY_FILE”
然后在数据库中以实际文件的方式创建函数
```sql
BEGIN
  PL4PY.create_func(i_func_name => 'list_table_sql.py',
                    i_dir  => 'PY_FILE',
                    i_file_name  =>'list_table_sql.py');
END;
  
declare
  r varchar2(4000);
  i_data varchar2(4000);
begin
  i_data:='{"sql":"select abc from def,ghi j,k.lmn o","mode":"T"}';
  r := pl4py.call_func_Eval(i_func_name =>'list_table_sql.py', i_data=>i_data);
  dbms_output.put_line(r);
end;

{"tablename": ["def", "ghi", "k.lmn"]}
```  

## 注意事项:
1. 服务被设计成长期运行的schedule_job，函数动态切换，因此除非要完全停止或者检查问题，一般不需要执行 PL4PY.stop_service
2. i_func_name参数必须带后缀 ".py"  
3. 视图 "pl4py_func_list_v"提供自定义python函数脚本内容的查询  

