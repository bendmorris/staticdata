hxdata is a simple helper to create Haxe values from structured data files (such 
as XML) at compile time.

To use, define the structure of your XML data in an abstract using the @:a 
metadata on fields:

```
@:dataPath("data/dogs.xml")
@:dataNode("breed")
@:build(hxdata.macros.DataEnum.build())
@:enum
abstract DogBreed(String) from String to String
{
    @:index(name) public static byColor:Map<UInt, Array<DogBreed>>;

    @:a public var name:String = "???";
    @:a(synonym) public var synonyms:Array<String>;
    @:a public var color:UInt;
    @:a(stat) public var stats:Map<String, Int>;
}
```

The corresponding XML file:

```
<dogs>
    <breed id="husky" name="Siberian Husky" color="0xc0c0c0">
        <synonym>Giant Wolfdog</synonym>
        <synonym>Big Fluffy Guy</synonym>
        <stat type="strength">10</stat>
        <stat type="obedience">1</stat>
    </breed>
</dogs>
```

Now you can access these values as @:enum abstracts in your code, with the 
members defined in the abstract:

```
var value1 = DogBreed.Husky;
trace(value1.name);
trace(value1.synonyms);
trace(value1.stats['strength']);
```
