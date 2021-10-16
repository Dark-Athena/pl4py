create or replace view pl4py_func_list_v as
select
       A.func_name,
       PL4PY.file2clob(D.DIRECTORY_NAME,  A.FUNC_NAME) CONTENTS,
       D.DIRECTORY_PATH || '\'  || A.FUNC_NAME FULL_DIR,
       A.last_update_datetime
  from pl4py_func_list a, dba_directories d
 where d.DIRECTORY_NAME = 'PY_FILE';
