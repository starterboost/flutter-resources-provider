# resources_provider

Provides a simple interface to a local directory of resources, with the option to sync with an online resource provider such as [Node-Resource-Provider](https://github.com/starterboost/node-resources-provider)

## See test

```
Directory dirTemp = Directory.current;

final resourceSync = ResourceProvider( 
	dirTarget: Directory( path.join( dirTemp.path, '../temp/resources' ).toString() )  
);

//get the current list of files
List<Resource> list = await resourceSync.getFiles();
//resync the content with an online provider
await resourceSync.sync( 'http://localhost:4000/resources' );
```
