import pytrie

"""
trie = {}

for i in range (0, 10000000):

	addition = str(i)
	trie[addition] = addition
"""
"""
dict = {}

for i in range (0, 1000000):

	addition = str(i)
	dict[addition] = addition
"""	
#work = []

trie = pytrie.Trie()

#trie["1"] = "1"
#trie["2"] = "2"

#trie2 = pytrie.Trie()
#trie2.add("2", "2")

#trie.add_dictionary(dict)

for i in range (0, 1000000):
	addition = str(i)
#	#trie.add(addition, addition)
	trie[addition] = addition
#for i in range (0, 10000000):
items = trie.items()
print trie
#print work

#for i in range(0, 10000000):
#	trie1 += trie2

#print len(trie)

#items = trie.dictionary()
#print items
#print len(keys)

#new_trie = trie.copy()
#items = new_trie.items()
#print items


#trie.add("1", "1")
#trie.add("12345", "12345")
#	
#trie.remove_clean("12345")

#trie.add("abc", "def")
#trie.add("ghi", "jkl")
	
#print trie.get("ghi")

#for i in range(0, 1000000):
#	trie.remove(str(i))
#work = {"abc": "cde", "fgh": "ijk"}
#print work

#print work.__hash__()
	
#for i in range(0, 1000000):
#	foo = trie.get(str(i))
#	foo = trie[str(i)]
#	print foo

