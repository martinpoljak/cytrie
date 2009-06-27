import pytrie

"""
trie = {}

for i in range (0, 1000000):

	addition = str(i)
	trie[addition] = addition
"""
	

trie = pytrie.Trie()

for i in range (0, 1000000):
	addition = str(i)
	
	trie.add(addition, addition)


	
for i in range(0, 1000000):
	foo = trie.get(str(i))
#	foo = trie[str(i)]

