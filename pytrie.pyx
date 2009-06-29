
include "platform.pxi"

#####

cdef extern from "stdlib.h":
	void *malloc(size_t size)
	void free(void *ptr)
	
cdef extern from "string.h":
	size_t strlen(char *str)
	void* memset(void *buffer, int ch, size_t count)
	 
#####

# purge(key)
# remove(key) -- OK
# reversed()
# dictionary()
# len() -- OK
# clear()
# fromkeys(seq[, value)
# copy()
# get(key[, default]) -- only as get(key)
# has_key(key) -- OK
# items()
# keys()
# setdefault(key[, default])
# update([other])
# values()
# del d[key]
# key in d
# key not in d
# d[key]

cdef struct Node:
	Node **subnodes[CHUNKS_COUNT]
	char *value
	CONTENT_MAP_TYPE content_map

	
cdef class Trie:
	
	cdef Node *_root
	cdef int _len
	
	def __cinit__(Trie self):
		self._root = self._create_node()
		
	def __init__(Trie self, dict dictionary = {}):
		if len(dictionary) > 0:
			self.add_dictionary(dictionary)
		
	def __dealloc__(Trie self):
		self._dealloc_node(self._root)
		
	cdef inline void _dealloc_node(Trie self, Node* node):
		
		cdef int chunks_count = CHUNKS_COUNT - 1
		cdef int chunk_size = CHUNK_SIZE - 1
		cdef Node *processed_node
		cdef int i, j
		
		# Deallocates the node structures
		if node.content_map:
			for i in range(0, chunks_count):
				if node.content_map & (1 << i):
					for j in range(0, chunk_size):
						processed_node = node.subnodes[i][j]
						
						if processed_node != NULL:
							self._dealloc_node(processed_node)
						
					free(node.subnodes[i])
					
		# Deallocates the node
		free(node)
		
	cdef inline Node* _create_node(Trie self):
		
		cdef Node *new_node = <Node *> malloc(sizeof(Node))
		new_node.content_map = 0
		
		return new_node
			
	cdef inline Node* _find_node(Trie self, char *key):
		
		cdef Node *current_node = self._root
		cdef int length = strlen(key) - 1
		cdef int i
		
		for i in range(0, length):
			current_node = self._get_subnode(current_node, key[i])
			
			if current_node == NULL:		
				break
			
		return current_node
		
		
	cdef inline Node* _get_subnode(Trie self, Node *node, char position):
		
		cdef int chunk
		cdef Node *result
		
		if node.content_map:
			chunk = (position & CHUNK_IDENTIFICATION_MASK) >> CHUNK_IDENTIFICATION_ALIGNMENT		
			
			if node.content_map & (1 << chunk):
				result = node.subnodes[chunk][position & BIT_POSITION_MASK]
			else:
				result = NULL
		else:
			result = NULL
				
		return result
		
	cdef inline void _write_subnode(Trie self, Node *node, Node *subnode, char position):
		
		cdef int _chunk_size = sizeof(Node *) * CHUNK_SIZE
		
		cdef int chunk = ((position & CHUNK_IDENTIFICATION_MASK) >> CHUNK_IDENTIFICATION_ALIGNMENT)
		cdef CONTENT_MAP_TYPE mask = 1 << chunk
		
		if not (node.content_map & mask):
			node.subnodes[chunk] = <Node**> malloc(_chunk_size)
			memset(node.subnodes[chunk], 0, _chunk_size)
		
		node.content_map = node.content_map | mask
		node.subnodes[chunk][position & BIT_POSITION_MASK] = subnode
	
	
	cpdef add(Trie self, char *key, char *value):
		
		cdef char character
		cdef Node *working_node	
		cdef int i
		
		cdef Node *current_node = self._root
		cdef int length = strlen(key) - 1		
		
		for i in range(0, length):
			
			character = key[i]
			working_node = self._get_subnode(current_node, character)
			
			if working_node == NULL:
				working_node = self._create_node()
				self._write_subnode(current_node, working_node, character)
			
			current_node = working_node
		
		current_node.value = value
		self._len += 1
		
		
	cpdef add_dictionary(Trie self, dict dictionary):
		
		cdef char *string
		
		for key, item in dictionary.items():
			string = _ = str(item)
			self.add(key, string)
			
		
	def get(Trie self, char *key):
		
		cdef Node *node = self._find_node(key)
		
		if node == NULL:
			raise KeyError
		
		return node.value
		
	def has_key(Trie self, char *key):
		
		if self._find_node(key):
			return True
		else:
			return False
			
			
	def remove(Trie self, char *key):
		
		cdef int key_length = strlen(key) - 1
		
		
		# Looks for node
		
		cdef Node *current_node = self._root
		cdef int length = key_length - 1
		cdef int i
		
		for i in range(0, length):
			current_node = self._get_subnode(current_node, key[i])
			
			if current_node == NULL:		
				break
		
		# Removes him
		
		cdef char position
		cdef int chunk
		cdef int bit
		cdef Node **chunks
		
		if current_node:
			
			position = key[key_length]
			
			if current_node.content_map:
			
				chunk = ((position & CHUNK_IDENTIFICATION_MASK) >> CHUNK_IDENTIFICATION_ALIGNMENT)
				
				if (current_node.content_map & (1 << chunk)):
					
					bit = position & BIT_POSITION_MASK
					chunks = current_node.subnodes[chunk]
					
					self._dealloc_node(chunks[bit])
					chunks[bit] = NULL
					
