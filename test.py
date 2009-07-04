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
#trie.add_dictionary(dict)

for i in range (0, 1000000):
	addition = str(i)
	trie.add(addition, addition)

items = trie.items()
print items[0:100]
#print len(keys)


#trie.add("1", "1")
#trie.add("12345", "12345")
#	
#trie.remove_clean("12345")

#trie.add("abc", "def")
#trie.add("ghi", "jkl")
	
#print trie.get("ghi")

#for i in range(0, 1000000):
#	trie.remove(str(i))
	
#for i in range(0, 1000000):
#	foo = trie.get(str(i))
#	foo = trie[str(i)]

