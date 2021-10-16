create or replace package PL4PY is
  
  /*
  name:pl4py
  purpose:call python function in plsql
  author:DarkAthena
  github:github.com/Dark-Athena
  email:darkathena@qq.com
  created_date:2021-10-14
  last_modified_date:2021-10-16
  */
  
  /*
  Copyright DarkAthena(darkathena@qq.com)
  
     Licensed under the Apache License, Version 2.0 (the "License");
     you may not use this file except in compliance with the License.
     You may obtain a copy of the License at
  
         http://www.apache.org/licenses/LICENSE-2.0
  
     Unless required by applicable law or agreed to in writing, software
     distributed under the License is distributed on an "AS IS" BASIS,
     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
     See the License for the specific language governing permissions and
     limitations under the License.
  */
  G_OS_PYEXE_PATH VARCHAR2(200) := 'C:\Users\wangyongyu\AppData\Local\Programs\Python\Python39\python.exe';
  G_service_NAME  VARCHAR2(20) := 'py_http_service';
  G_service_port  number := 8888;
  G_forbid        varchar2(1) := 'Y';
  G_PY_FILE_dir   varchar2(200) := 'PY_FILE';
  g_content_type  varchar2(200) := 'application/x-www-form-urlencoded';
  invalid_filename  EXCEPTION;
  invalid_path      EXCEPTION;
  invalid_operation EXCEPTION;
  PRAGMA EXCEPTION_INIT(invalid_filename, -29288);
  PRAGMA EXCEPTION_INIT(invalid_path, -29280);
  PRAGMA EXCEPTION_INIT(invalid_operation, -29283);
  function file2clob(p_dir varchar2, p_file_name varchar2) return clob;

  /*--create a user-defined Python function ,and the name is same as i_func_name's shortname
  BEGIN
  PL4PY.create_func(i_func_name => 'sample_f.py',
                    i_contents  => q'{def sample_f(num):
    return float(num)*float(num)}');
  END;
  */                        
  procedure create_func(i_func_name varchar2, i_contents clob);
  
  /*if you has been saved py file in os ,also can defined dir and file's name to create
  BEGIN
  PL4PY.create_func(i_func_name => 'sample_f.py',
                    i_dir  => 'PY_FILE',
                    i_file_name  =>'sample_f_test.py');
  END;
  */
  procedure create_func(i_func_name varchar2,
                        i_dir       varchar2,
                        i_file_name varchar2);
 
  /*--drop a user-defined Python function
  BEGIN
  PL4PY.drop_func(i_func_name => 'sample_f.py');
  END;*/
  procedure drop_func(i_func_name varchar2);
  
  /*--start service
  begin
    start_service;
  end;*/
  procedure start_service;
  
  /*--stop service
  begin
    stop_service;
  end;*/
  procedure stop_service;
  
  /*--call a user-defined Python function 
  select  pl4py.call_func_Eval(i_func_name =>'sample_f.py', i_data=>6) r from dual;
  */
  function call_func_Eval(i_func_name varchar2, i_data clob) return clob;

end PL4PY;
/
create or replace package body PL4PY is
  G_service_Script VARCHAR2(4000) := q'{import flask, json,os
import importlib
from flask import request
import running
server = flask.Flask(__name__)
@server.route('/func', methods=['get', 'post'])
def login():
    filename=request.values.get('func_name')
    filepath, tmpfilename = os.path.split(filename)
    shotname, extension = os.path.splitext(tmpfilename)
    moudle = importlib.import_module(shotname)
    importlib.reload(moudle)
    my_function = getattr(moudle, shotname)
    data = request.values.get('data')
    a=my_function(data)
    return json.dumps(a)

if __name__ == '__main__':
    server.run(debug=True, port=8888, host='0.0.0.0')}';

  FUNCTION post(i_url VARCHAR2, i_post_data CLOB) RETURN VARCHAR2 IS
    req               utl_http.req;
    resp              utl_http.resp;
    VALUE             VARCHAR2(4000);
    l_http_return_msg VARCHAR2(4000);
  BEGIN
    req := utl_http.begin_request(i_url, 'POST', 'HTTP/1.1');
    utl_http.set_header(req, 'Content-Type', g_content_type);
    utl_http.set_header(req,
                        'Content-Length',
                        dbms_lob.getlength(i_post_data));
    DECLARE
      sizeb  INTEGER := 1440;
      buffer VARCHAR2(1440);
      offset INTEGER DEFAULT 1;
    BEGIN
      LOOP
        BEGIN
          dbms_lob.read(i_post_data, sizeb, offset, buffer);
        EXCEPTION
          WHEN no_data_found THEN
            EXIT;
        END;
        offset := offset + sizeb;
        utl_http.write_text(req, buffer);
      END LOOP;
    END;
    resp := utl_http.get_response(req);
    utl_http.read_raw(resp, VALUE, 2000);
    utl_http.end_response(resp);
    l_http_return_msg := utl_raw.cast_to_varchar2(VALUE);
    RETURN l_http_return_msg;
  EXCEPTION
    WHEN OTHERS THEN
      utl_http.close_persistent_conns;
      utl_tcp.close_all_connections;
      l_http_return_msg := SQLERRM;
      RETURN l_http_return_msg;
  END;

  function url_decode_clob(i_clob clob) return clob is
    sizeB  integer := 1440;
    buffer VARCHAR2(30000);
  
    offset integer default 1;
    o_clob clob;
  begin
    dbms_lob.createtemporary(o_clob, false);
    loop
      begin
        dbms_lob.read(i_clob, sizeB, offset, buffer);
      exception
        when no_data_found then
          exit;
      end;
      offset := offset + sizeB;
      buffer := utl_url.escape(buffer, true, url_charset => 'UTF-8');
      dbms_lob.append(o_clob, buffer);
    end loop;
    return o_clob;
  END;
  
  function get_os_dir return varchar2 is
    l_os_dir varchar2(2000);
  begin
  
    select D.DIRECTORY_PATH
      into l_os_dir
      from dba_directories d
     where d.DIRECTORY_NAME = G_PY_FILE_dir;
    RETURN l_os_dir;
  end;
  
  PROCEDURE os_cmd(I_db_Path  IN VARCHAR2,
                   l_cmd      IN VARCHAR2,
                   I_job_name IN VARCHAR2) IS
  
    l_dir varchar2(4000);
  begin
    select h.DIRECTORY_PATH
      into l_dir
      from ALL_DIRECTORIES h
     where h.DIRECTORY_NAME = I_db_Path
       and rownum = 1;
  
    BEGIN
      SYS.DBMS_SCHEDULER.CREATE_JOB(job_name        => I_job_name,
                                    start_date      => sysdate +
                                                       5 / 24 / 60 / 60,
                                    repeat_interval => 'Freq=Secondly;Interval=5',
                                    end_date        => NULL,
                                    job_class       => 'DEFAULT_JOB_CLASS',
                                    job_type        => 'EXECUTABLE',
                                    job_action      => l_cmd,
                                    comments        => NULL);
      SYS.DBMS_SCHEDULER.SET_ATTRIBUTE(name      => I_job_name,
                                       attribute => 'RESTARTABLE',
                                       value     => FALSE);
      SYS.DBMS_SCHEDULER.SET_ATTRIBUTE(name      => I_job_name,
                                       attribute => 'LOGGING_LEVEL',
                                       value     => SYS.DBMS_SCHEDULER.LOGGING_OFF);
      SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL(name      => I_job_name,
                                            attribute => 'MAX_FAILURES');
      SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL(name      => I_job_name,
                                            attribute => 'MAX_RUNS');
      BEGIN
        SYS.DBMS_SCHEDULER.SET_ATTRIBUTE(name      => I_job_name,
                                         attribute => 'STOP_ON_WINDOW_CLOSE',
                                         value     => FALSE);
      EXCEPTION
        -- could fail if program is of type EXECUTABLE...
        WHEN OTHERS THEN
          NULL;
      END;
      SYS.DBMS_SCHEDULER.SET_ATTRIBUTE(name      => I_job_name,
                                       attribute => 'JOB_PRIORITY',
                                       value     => 3);
      SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL(name      => I_job_name,
                                            attribute => 'SCHEDULE_LIMIT');
      SYS.DBMS_SCHEDULER.SET_ATTRIBUTE(name      => I_job_name,
                                       attribute => 'AUTO_DROP',
                                       value     => FALSE);
      SYS.DBMS_SCHEDULER.ENABLE(name => I_job_name);
    END;
  
  EXCEPTION
    WHEN OTHERS THEN
      raise;
  END;
  
  FUNCTION Clob2Blob(v_blob_in IN CLOB) RETURN BLOB IS
  
    v_file_clob    BLOB;
    v_file_size    INTEGER := dbms_lob.lobmaxsize;
    v_dest_offset  INTEGER := 1;
    v_src_offset   INTEGER := 1;
    v_blob_csid    NUMBER := dbms_lob.default_csid;
    v_lang_context NUMBER := dbms_lob.default_lang_ctx;
    v_warning      INTEGER;
  
  BEGIN
  
    dbms_lob.createtemporary(v_file_clob, TRUE);
  
    dbms_lob.converttoBlob(v_file_clob,
                           v_blob_in,
                           v_file_size,
                           v_dest_offset,
                           v_src_offset,
                           v_blob_csid,
                           v_lang_context,
                           v_warning);
  
    RETURN v_file_clob;
  
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('Error found');
    
  END;

  procedure blob2file(p_blob      blob,
                      p_directory varchar2,
                      p_filename  varchar2) is
    t_fh  utl_file.file_type;
    t_len pls_integer := 32767;
  begin
    t_fh := utl_file.fopen(p_directory, p_filename, 'wb');
    for i in 0 .. trunc((dbms_lob.getlength(p_blob) - 1) / t_len) loop
      utl_file.put_raw(t_fh, dbms_lob.substr(p_blob, t_len, i * t_len + 1));
    end loop;
    utl_file.fclose(t_fh);
  end;
  --
  procedure clob2file(p_blob      clob,
                      p_directory varchar2,
                      p_filename  varchar2) is
  BEGIN
    blob2file(Clob2Blob(p_blob), p_directory, p_filename);
  end;

  procedure start_service is
    l_service_Script clob;
    l_cmd            varchar2(4000);
  begin
    l_service_Script := G_service_Script;
    l_service_Script := replace(l_service_Script,
                                'port123321',
                                G_service_port);
  
    clob2file('pass;', G_PY_FILE_dir, 'running.py');
    clob2file(l_service_Script, G_PY_FILE_dir, G_service_NAME);
    l_cmd := G_OS_PYEXE_PATH || ' ' || get_os_dir || '\' || G_service_NAME;
    os_cmd(G_PY_FILE_dir, l_cmd, G_service_NAME);
  end;

  procedure stop_service is
  begin
    begin
      utl_file.fremove(G_PY_FILE_dir, 'running.py');
      dbms_lock.sleep(5);
    exception
      when invalid_filename then
        null;
      when invalid_path then
        null;
      when invalid_operation then
        null;
    end;
    begin
      dbms_scheduler.drop_job(G_service_NAME);
    exception
      WHEN OTHERS then
        null;
    end;
  
  end;

  function file2clob(p_dir varchar2, p_file_name varchar2) return clob is
    file_lob      bfile;
    file_blob     clob;
    warning       number;
    dest_offset   number := 1;
    source_offset number := 1;
    lang_ctx      integer := DBMS_LOB.DEFAULT_LANG_CTX;
    src_csid      number := NLS_CHARSET_ID('UTF8');
  begin
    file_lob := bfilename(p_dir, p_file_name);
    dbms_lob.open(file_lob, dbms_lob.file_readonly);
    dbms_lob.createtemporary(file_blob, true);
    dbms_lob.loadclobfromfile(dest_lob     => file_blob,
                              src_bfile    => file_lob,
                              amount       => dbms_lob.lobmaxsize,
                              dest_offset  => dest_offset,
                              src_offset   => source_offset,
                              bfile_csid   => src_csid,
                              lang_context => lang_ctx,
                              warning      => warning);
    dbms_lob.close(file_lob);
    return file_blob;
  exception
    when others then
      if dbms_lob.isopen(file_lob) = 1 then
        dbms_lob.close(file_lob);
      end if;
      if dbms_lob.istemporary(file_blob) = 1 then
        dbms_lob.freetemporary(file_blob);
      end if;
      raise;
  end;

  procedure update_func(i_func_name varchar2, i_contents clob) is
  BEGIN
    UPDATE PL4PY_FUNC_LIST PFL
       SET PFL.Last_Update_Datetime = sysdate
     WHERE PFL.FUNC_NAME = i_func_name;
    clob2file(i_contents, G_PY_FILE_dir, i_func_name);
    COMMIT;
  END;

  procedure create_func(i_func_name varchar2,
                        i_dir       varchar2,
                        i_file_name varchar2) is
    l_contents clob;
  begin
    l_contents := file2clob(i_dir, i_file_name);
    create_func(i_func_name, l_contents);
  end;

  procedure create_func(i_func_name varchar2, i_contents clob) is
    l_exists number;
  begin
    G_forbid := 'N';
    select count(1)
      into l_exists
      from PL4PY_FUNC_LIST pfl
     where pfl.func_name = i_func_name;
    if l_exists > 0 then
      update_func(i_func_name, i_contents);
    else
      insert into PL4PY_FUNC_LIST (FUNC_NAME) values (i_func_name);
      clob2file(i_contents, G_PY_FILE_dir, i_func_name);
      COMMIT;
    end if;
  end;

  procedure drop_func(i_func_name varchar2) is
  begin
    G_forbid := 'N';
  
    delete PL4PY_FUNC_LIST pfl where pfl.func_name = i_func_name;
    begin
      utl_file.fremove(G_PY_FILE_dir, i_func_name);
    exception
      when invalid_filename then
        null;
      when invalid_path then
        null;
      when invalid_operation then
        null;
    end;
    commit;
  end;

  function call_func_Eval(i_func_name varchar2, i_data CLOB) return clob is
    l_resp   varchar2(4000);
    L_EXISTS NUMBER;
    l_param  clob;
  begin
    SELECT COUNT(1)
      INTO L_EXISTS
      FROM PL4PY_FUNC_LIST PFL
     WHERE PFL.FUNC_NAME = i_func_name;
    IF L_EXISTS <> 1 THEN
      RETURN '{"msg":"funcation name error!"}';
    END IF;
    dbms_lob.createtemporary(l_param, TRUE);
    dbms_lob.open(l_param, dbms_lob.lob_readwrite);
    l_param := 'func_name=' || url_decode_clob(i_func_name) || '&data=';
    dbms_lob.append(l_param, url_decode_clob(i_data));
    l_resp := post('http://localhost:' || G_service_port || '/func',
                   l_param);
    return l_resp;
  end;

end PL4PY;
/
