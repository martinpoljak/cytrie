
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

# purge(key) -- OK, as remove_clean(key)
# remove(key) -- OK
# reversed()
# dictionary()
# len() -- OK
# clear()
# clean()
# fromkeys(seq[, value)
# copy()
# get(key[, default]) -- OK, only as get(key)
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

cdef struct Node	# Forward

cdef struct TraversingHelper:
	int last_chunk
	int last_bit
	CONTENT_MAP_TYPE content_map
	
cdef struct NodePosition:
	Node *node
	int chunk
	int bit

cdef struct Node:
	Node **subnodes[CHUNKS_COUNT]
	char *value
	
	int subnodes_count
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

	"""
	
	# Probably not compatible with Cython at this time (because of 'isclass')
	
	def __init__(Trie self, iterable = []):
		if len(iterable) > 0:
			if isclass(iterable, dict):
				self.add_dictionary(iterable)
			else:
				self.add_iterable(iterable)
	"""

		
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
		cdef NodePosition *pn_info = &(node.parent)
		
		if node.parent.node:
			pn_info.node.subnodes[pn_info.chunk][pn_info.bit] = NULL
			pn_info.node.subnodes_count -= 1
			
		# Do
		
		while current_node != node.parent.node:

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
			current_node = current_node.parent.node
			
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
		new_node.subnodes_count = 0
		
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
		current_node._traversing.content_map = current_node.content_map
		
		while current_node != node.parent.node:

			# Traversing
			while current_node._traversing.content_map:
				
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
								processed_node._traversing.content_map = processed_node.content_map
								
								current_node = processed_node
								
								break_it = True
								break
							
						if break_it:
							break_it = False
							break
					
						current_node._traversing.content_map = current_node._traversing.content_map ^ mask
			
			# Deallocating the node content
			if current_node.has_content:
				self._len -= 1
				print current_node.value
				current_node.has_content = False
			
			current_node = current_node.parent.node
		
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
		node.subnodes_count += 1
		
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
				working_node.subnodes_count = 0
				
				self._write_subnode(current_node, working_node, character)
			
			current_node = working_node
		
		current_node.value = value
		current_node.has_content = True
		
		self._len += 1
		
	cpdef add(Trie self, char *key, char *value):
		
		cdef int length = strlen(value) + 1
		cdef char *_value = <char *> malloc(sizeof(char) * length)
		strncpy(_value, value, length)
		
		self._add(key, _value)
		
	def add_dictionary(Trie self, dict dictionary):
		
		cdef char *string
		
		for key, item in dictionary.items():
			string = _ = str(item)
			self.add(key, string)
			
	def add_iterable(Trie self, iterable):
		
		cdef char *string
				
		for item in iterable:
			string = _ = str(item)
			self.add(string, string)
		
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
	
	def remove_clean(Trie self, char *key):
		cdef Node *node = self._find_node(key)
		cdef Node *parent_node
		
		if node:
			if node.subnodes_count > 0:
				node.has_content = False
			
			else:
				parent_node = node.parent.node
				
				while True:
					
					if (parent_node == NULL) or(parent_node.subnodes_count > 1) or parent_node.has_content:
						self._dealloc_node(node)
						break
					else:
						node = parent_node
						parent_node = node.parent.node
						
			self._len -= 1
						
			
	def cut(Trie self, char *mask):
		cdef Node *node = self._find_node(mask)
		
		if node:
			self._cut_node(node)
	
	def cut_clean(Trie self, char *mask):
		cdef Node *node = self._find_node(mask)
		
		if node:
			self._dealloc_node(node)
	
