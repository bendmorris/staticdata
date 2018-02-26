package staticdata;

import staticdata.data.*;

class ExamplesTest extends TestCase
{
	public function testDogs()
	{
		assertEquals("Siberian Husky", DogBreed.Husky.name);
		assertArrayEquals(["Giant Wolfdog", "Big Fluffy Guy"], DogBreed.Husky.synonyms);
		assertEquals(10, DogBreed.Husky.stats["strength"]);
		assertEquals(1, DogBreed.Husky.stats["obedience"]);
	}

	public function testBirds()
	{
		assertEquals(1, BirdType.SpottedEagle);
	}

	public function testFruit()
	{
		assertArrayEquals([FruitColor.Red, FruitColor.Yellow], FruitType.Apple.colors);
	}

	public function testUpgrades()
	{
		assertEquals(UpgradeCategory.Fighting, UpgradeType.FightingAtk.category);
	}
}
