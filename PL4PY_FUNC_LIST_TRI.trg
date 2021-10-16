create or replace trigger PL4PY_FUNC_LIST_TRI
  before insert OR update OR delete
  on PL4PY_FUNC_LIST 
  for each row
declare
  -- local variables here
begin
  IF PL4PY.G_forbid='Y' THEN 
   Raise_application_error(-20001, 'THIS OPERATION IS FORBID,PLEASE USE PROCEDURE IN PL4PY');
    END IF;
END;
/
