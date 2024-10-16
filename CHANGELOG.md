## 0.0.5 (https://github.com/ThomasDevApps/flutter_supabase_macro/pull/5)

Add a named parameter for each field of the class.
For example, if class contain a field named `id` then `bool? removeId` 
will be added as a named parameter of `toJsonSupabase`.

If `removeId` is not null and true, then `id` will not be add the json.

## 0.0.4 (https://github.com/ThomasDevApps/flutter_supabase_macro/pull/4)

Only exclude `primaryKey` from the Map if :
- Can't be nullable then check that `!= null`
- The type is `String`, then check that the value `isNotEmpty`


## 0.0.1 (https://github.com/ThomasDevApps/flutter_supabase_macro/pull/1)

Initial release : 
- Creation of a `toJsonSupabase` which exclude the `primaryKey` from the `Map`