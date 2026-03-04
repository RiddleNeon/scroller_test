select indexname, tablename
from pg_indexes
where schemaname = 'public'
order by tablename;