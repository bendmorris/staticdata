`staticdata` is a library that manages "static data" - sets of data that don't 
change at runtime, with one or more variants that share a common schema of 
associated information. `staticdata` creates Haxe enum abstracts for each type 
of data and makes it easy to access their associated attributes in a type-safe 
way.

## Getting started

### Schema

To use `staticdata`, define the structure of your data in an abstract by using 
the @:a metadata to mark data fields:

```haxe
@:build(staticdata.macros.DataEnum.build(["data/dogs.xml"], "breed"))
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

### Data

The corresponding XML file:

```xml
<dogs>
    <breed id="husky" name="Siberian Husky" color="0xc0c0c0">
        <synonym>Giant Wolfdog</synonym>
        <synonym>Big Fluffy Guy</synonym>
        <stat type="strength">10</stat>
        <stat type="obedience">1</stat>
    </breed>
</dogs>
```

Or YAML:

```yaml
breed:
  - id: husky
    name: Siberian Husky
    color: 0xc0c0c0
    synonym: ["Giant Wolfdog", "Big Fluffy Guy"]
    stat:
      strength: 10
      obedience: 1
```

### Access

Now you can access these values as @:enum abstracts in your code, with the 
members defined in the abstract:

```
var value1 = DogBreed.Husky;
trace(value1.name);
trace(value1.synonyms);
trace(value1.stats['strength']);
```

## Details

### Underlying types

The enum abstract can use *any* convenient underlying type. For String 
abstracts, the value will be assumed to be the same as the ID if none is 
specified. Otherwise, you can specify the variant's runtime value using the 
`value` field:

```haxe
@:build(staticdata.macros.DataEnum.build(["data/fruit.yaml"], "fruit"))
@:enum
abstract FruitType(Int) from Int to Int
{
    @:a public var name:String = "???";
    @:a public var color:UInt;
}
```

```yaml
fruit:
- id: apple
  value: 1
  color: 0xff0000
```

### IDs

Static data variants have identifiers which are used to reference them in other 
data or in code. `staticdata` uses a convention of "snake_case" identifiers in 
data that correspond to TitleCase enum variants in code:

```haxe
@:build(staticdata.macros.DataEnum.build(["data/bird.yaml"], "birds"))
@:enum
abstract BirdType(Int) from Int to Int
{
    @:a public var name:String = "???";
}
```

```yaml
birds:
- id: spotted_eagle
  value: 1
  name: "Spotted Eagle"
```

The data is accessed in code using TitleCase:

```haxe
class Main {
    static function main() {
        trace(BirdType.SpottedEagle.name);
    }
}
```

### Default field values

Field values with a default don't need to be specified in the data. Field values 
with no default are required, even if the type is nullable; specify `null` as 
the default if that's what you want.

### Supported types

`staticdata` supports the following types of data:

- Primitivies: `String`, `Int`, `Float`, `Bool`
- Arrays of supported values (specify with a YAML list or multiple XML child nodes)
- StringMap (specify with a nested YAML object or XML child nodes; see above)
- Custom types; use "``" to inject Haxe code directly as values

### Links between other models

`staticdata` aims to make static data types easily interoperable. Therefore, 
when the type of a field is another enum abstract, the parser will assume that 
it follows the ID convention above and will try to refer to it in a type-safe 
way:

```haxe
@:build(staticdata.macros.DataEnum.build(["data/bird.yaml"], "fruit"))
@:enum
abstract FruitType(String) from String to String
{
    @:a public var name:String;
    @:a public var colors:Array<FruitColor>;
}

@:build(staticdata.macros.DataEnum.build(["data/fruit.yaml"], "colors"))
@:enum
abstract FruitColor(UInt) from UInt to UInt
{
    @:a public var name:String;
}
```

```yaml
fruit:
- id: apple
  name: "Red Delicious Apple"
  colors:
  - red
  - yellow

colors:
- id: red
  name: "Apple Red"
  value: 0xff0000
- id: yellow
  name: "Golden Yellow"
  value: 0xd4aa00
```

When the code for the `FruitType` variants is generated, the value for 
`FruitType.Apple.Color` will be `[FruitColor.Red, FruitColor.Yellow]`.

Currently there's no way to disable this inference, but such an option could be 
added in the future.

### Field access

The generated code to access variant attributes may use one of three strategies:

- A generated `switch` statement
- An array of values, with an array index generated for each variant
- A map of values

`staticdata` will use heuristics based on field type and number of variants to 
choose which one to use.
