## 0.0.1

Initial release : 
- Creation of a `toJsonSupabase` which exclude the `primaryKey` from the `Map`

## 0.0.4

Only exclude `primaryKey` from the Map if :
- `!= null`
- If `String`, `.isNotEmpty`