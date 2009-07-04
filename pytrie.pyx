
include "platform.pxi"

#####

cdef extern from "stdlib.h":
	void *malloc(size_t size)
	void free(void *ptr)
	
cdef extern from "string.h":
	size_t strlen(char *str)
	void* memset(void *buffer, int ch, size_t count)
	void* strncpy(char *destination, char *source, size_t count)
	 
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


cdef struct TraversingHelper:
	int last_chunk
	int last_bit
	CONTENT_MAP_TYPE bitmap
	
cdef struct NodePosition:
	void *node
	int chunk
	int bit

cdef struct Node:
	Node **subnodes[CHUNKS_COUNT]
	char *value
	int has_content
	CONTENT_MAP_TYPE content_map
	TraversingHelper _traversing
	NodePosition parent



	
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

		"""
		Go around the tree non-recursive alghorithm.
		"""

		cdef Node *current_node = node
		cdef Node *processed_node
		cdef Node *deallocated_node
		
		cdef int break_it = False 
		cdef int i, j
		
		cdef CONTENT_MAP_TYPE mask
		
		current_node._traversing.last_chunk = 0
		current_node._traversing.last_bit = 0
		
		# Clears the parent node record
		
		if node.parent.node:
			(<Node *> node.parent.node).subnodes[node.parent.chunk][node.parent.bit] = NULL
			
		# Do
		
		while current_node != <Node *> node.parent.node:

			# Traversing
			while current_node.content_map:
				
				for i in range(current_node._traversing.last_chunk, CHUNKS_COUNT):
					
					mask = 1 << i
					if node.content_map & mask:
						for j in range(current_node._traversing.last_bit, CHUNK_SIZE):
							processed_node = current_node.subnodes[i][j]

							if processed_node:
								current_node._traversing.last_chunk = i
								current_node._traversing.last_bit = j + 1
								
								processed_node._traversing.last_chunk = 0
								processed_node._traversing.last_bit = 0								
								
								current_node = processed_node
								
								break_it = True
								break
							
						if break_it:
							break_it = False
							break
						
						current_node.content_map = current_node.content_map ^ mask
						free(current_node.subnodes[i])
															
			deallocated_node = current_node
			current_node = <Node *> current_node.parent.node
			
			# Deallocating the node content
			if deallocated_node.has_content:
				self._len -= 1
				#print deallocated_node.value
				free(deallocated_node.value)
			
			free(deallocated_node)
			
			
			
		#print "return"
		
		"""
		cdef Node *processed_node
		cdef int i, j
		
		# Traverses through the tree
		if node.content_map:
			for i in range(0, CHUNKS_COUNT):
				if node.content_map & (1 << i):
					for j in range(0, CHUNK_SIZE):
						processed_node = node.subnodes[i][j]
						
						if processed_node:
							self._dealloc_node(processed_node)
						
					free(node.subnodes[i])
					
		if node.has_content:
			free(node.value)
			self._len -= 1
						
		# Deallocates the node
		free(node)
		"""
		
		
	cdef inline Node* _create_node(Trie self):
		
		cdef Node *new_node = <Node *> malloc(sizeof(Node))
		new_node.content_map = 0
		new_node.has_content = False
		new_node.parent.node = NULL
		
		return new_node
			
	cdef inline Node* _find_node(Trie self, char *key):
		
		cdef Node *current_node = self._root
		cdef int length = strlen(key)
		cdef int i
		
		for i in range(0, length):
			current_node = self._get_subnode(current_node, key[i])
			
			if current_node == NULL:
				break
			
		return current_node
		
	cdef inline void _cut_node(Trie self, Node *node):
		
		"""
		Go around the tree non-recursive alghorithm.
		"""

		cdef Node *current_node = node
		cdef Node *processed_node
		
		cdef int break_it = False 
		cdef int i, j
		
		cdef CONTENT_MAP_TYPE mask
		
		current_node._traversing.last_chunk = 0
		current_node._traversing.last_bit = 0
		current_node._traversing.bitmap = current_node.content_map
		
		while current_node != <Node *> node.parent.node:

			# Traversing
			while current_node._traversing.bitmap:
				
				for i in range(current_node._traversing.last_chunk, CHUNKS_COUNT):
					
					mask = 1 << i
					if node.content_map & mask:
						for j in range(current_node._traversing.last_bit, CHUNK_SIZE):
							processed_node = current_node.subnodes[i][j]

							if processed_node:
								current_node._traversing.last_chunk = i
								current_node._traversing.last_bit = j + 1
								
								processed_node._traversing.last_chunk = 0
								processed_node._traversing.last_bit = 0	
								processed_node._traversing.bitmap = processed_node.content_map
								
								current_node = processed_node
								
								break_it = True
								break
							
						if break_it:
							break_it = False
							break
					
						current_node._traversing.bitmap = current_node._traversing.bitmap ^ mask
			
			# Deallocating the node content
			if current_node.has_content:
				self._len -= 1
				print current_node.value
				current_node.has_content = False
			
			current_node = <Node *> current_node.parent.node
		
		"""
		cdef Node *processed_node
		cdef int i, j
		
		# Traverses through the tree
		if node.content_map:
			for i in range(0, CHUNKS_COUNT):
				if node.content_map & (1 << i):
					for j in range(0, CHUNK_SIZE):
						processed_node = node.subnodes[i][j]
						
						if processed_node:
							self._cut_node(processed_node)
							
					node.has_content = False
					self._len -= 1
		"""
		
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
		cdef int bit = position & BIT_POSITION_MASK
		
		cdef CONTENT_MAP_TYPE mask = 1 << chunk
		
		if not (node.content_map & mask):
			node.subnodes[chunk] = <Node**> malloc(_chunk_size)
			memset(node.subnodes[chunk], 0, _chunk_size)
		
		node.content_map = node.content_map | mask
		node.subnodes[chunk][bit] = subnode
		
		subnode.parent.node = node
		subnode.parent.chunk = chunk
		subnode.parent.bit = bit
	
	
	cdef inline void _add(Trie self, char *key, char *value):
		
		cdef char character
		cdef Node *working_node
		cdef int i
		
		cdef Node *current_node = self._root
		cdef int length = strlen(key)		
		
		for i in range(0, length):
			
			character = key[i]
			working_node = self._get_subnode(current_node, character)
			
			if working_node == NULL:				
				working_node = <Node *> malloc(sizeof(Node))
				working_node.content_map = 0
				working_node.has_content = False
				
				self._write_subnode(current_node, working_node, character)
			
			current_node = working_node
		
		current_node.value = value
		current_node.has_content = True
		
		self._len += 1
		
	def add(Trie self, char *key, char *value):
		
		cdef int length = strlen(value) + 1
		cdef char *_value = <char *> malloc(sizeof(char) * length)
		strncpy(_value, value, length)
		
		self._add(key, _value)
		
	cpdef add_dictionary(Trie self, dict dictionary):
		
		cdef char *string
		
		for key, item in dictionary.items():
			string = _ = str(item)
			self.add(key, string)
			
		
	def get(Trie self, char *key):
		
		cdef Node *node = self._find_node(key)
		
		if node == NULL:
			raise KeyError
		
		if node.has_content:
			return node.value
		else:
			raise KeyError
		
	def has_key(Trie self, char *key):
		
		if self._find_node(key):
			return True
		else:
			return False
	
	def remove(Trie self, char *key):
		cdef Node *node = self._find_node(key)
		
		if node:
			node.has_content = False
			self._len -= 1
	"""
	def remove_clean(Trie self, char *key):
		cdef Node *current_node = self._root
		cdef int length = strlen(key) - 2
		cdef int i
		
		for i in range(0, length):
			current_node = self._get_subnode(current_node, key[i])
			
			if current_node == NULL:		
				break
		
		if current_node
	"""
			
	def cut(Trie self, char *mask):
		cdef Node *node = self._find_node(mask)
		
		if node:
			self._cut_node(node)
	
	def cut_clean(Trie self, char *mask):
		cdef Node *node = self._find_node(mask)
		
		if node:
			self._dealloc_node(node)
	
