
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
# remove(key)
# getAll()
# getReversed()

cdef struct Node:
	Node **subnodes[CHUNKS_COUNT]
	char *value
	CONTENT_MAP_TYPE content_map
	
cdef class Trie:
	
	cdef Node *_root
	
	def __cinit__(Trie self):
		self._root = self._create_node()
		
	def __init__(Trie self, dictionary = {}):
		""""""
		
	def __dealloc__(Trie self):
		self._dealloc_node(self._root)
		""""""
		
	cdef inline void _dealloc_node(Trie self, Node* node):
		
		cdef int chunks_count = CHUNKS_COUNT - 1
		cdef int chunk_size = CHUNK_SIZE - 1
		cdef Node *processed_node
		cdef int i, j
		
		if node.content_map:
			for i in range(0, chunks_count):
				if node.content_map & (1 << i):
					for j in range(0, chunk_size):
						processed_node = node.subnodes[i][j]
						
						if processed_node != NULL:
							self._dealloc_node(processed_node)
						
					free(node.subnodes[i])
		free(node)
		
	cdef inline Node* _create_node(Trie self):
		
		cdef Node *new_node 		
		
		new_node = <Node *> malloc(sizeof(Node))
		new_node.content_map = 0
		
		return new_node
			
	cdef inline Node* _find_node(Trie self, char *key):
		
		cdef Node *current_node
		cdef int length = strlen(key) - 1
		cdef int i
		
		current_node = self._root

		for i in range(0, length):
			current_node = self._get_subnode(current_node, key[i])
			
			if current_node == NULL:		
				break
			
		return current_node
		
		
	cdef inline Node* _get_subnode(Trie self, Node *node, char position):
		
		cdef int chunk = (position & CHUNK_IDENTIFICATION_MASK) >> CHUNK_IDENTIFICATION_ALIGNMENT
		cdef int bit = position & BIT_POSITION_MASK
		cdef char mask = 1 << chunk
		
		cdef Node *result
		
		if node.content_map & mask:
			result = node.subnodes[chunk][bit]
		else:
			result = NULL
			
		return result
		
	cdef inline void _write_subnode(Trie self, Node *node, Node *subnode, char position):
		
		cdef int _chunk_size = sizeof(Node *) * CHUNK_SIZE
		
		cdef int chunk = ((position & CHUNK_IDENTIFICATION_MASK) >> CHUNK_IDENTIFICATION_ALIGNMENT)
		cdef int bit = position & BIT_POSITION_MASK
		cdef char mask = 1 << chunk
		
		if not (node.content_map & mask):
			node.subnodes[chunk] = <Node**> malloc(_chunk_size)
			memset(node.subnodes[chunk], 0, _chunk_size)
		
		node.content_map = node.content_map | mask
		node.subnodes[chunk][bit] = subnode
	
	
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
		
		
	cpdef get(Trie self, char *key):
		
		cdef Node *node = self._find_node(key)
		
		if node == NULL:
			raise KeyError
		
		return node.value


