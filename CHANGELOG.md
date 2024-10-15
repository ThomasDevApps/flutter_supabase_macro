## 0.0.1

Initial release : 
- Creation of a `toJsonSupabase` which exclude the `primaryKey` from the `Map`

## 0.0.4

Only exclude `primaryKey` from the Map if :
- Can't be nullable then check that `!= null`
- The type is `String`, then check that the value `isNotEmpty`