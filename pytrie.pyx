
include "platform.pxi"
include "common.pxi"

#####

cdef extern from "stdlib.h":
	void *malloc(size_t size)
	void *realloc(void *ptr, size_t size)
	void free(void *ptr)
	
cdef extern from "string.h":
	size_t strlen(char *str)
	void* memset(void *buffer, int ch, size_t count)
	void* strncpy(char *destination, char *source, size_t count)
	void* memcpy(void *destination, void *source, size_t length)
	 
#####

# purge(key) -- OK, as remove_clean(key)
# remove(key) -- OK
# reversed() -- CANCEL
# dictionary() -- OK
# len() -- OK
# clear() -- OK
# clean() -- OK
# fromkeys(seq[, value]) -- OK
# copy() -- OK
# get(key[, default]) -- OK, only as get(key)
# has_key(key) -- OK
# items() -- OK
# keys() -- OK
# setdefault(key[, default]) -- OK
# update([other]) -- OK
# values() -- OK
# del d[key] -- OK
# key in d -- OK
# key not in d -- OK
# d[key] -- OK
# + -- OK
# insert(trie) -- OK

# + fetching only some subtree by keys(), list(), dictionary(), reversed(), values() and copy() method
# + neodalokovavaji se pole jen oznacena has_content = False

cdef struct Node	# Forward

cdef struct TraversingHelper:
	int last_chunk
	int last_bit
	CONTENT_MAP_TYPE content_map
	
cdef struct NodePosition:
	int chunk
	int bit
	Node *node

cdef struct Node:
	Node **subnodes[CHUNKS_COUNT]
	char *value
	TraversingHelper _traversing
	
	int subnodes_count
	int flags
	CONTENT_MAP_TYPE content_map
	NodePosition parent


#define FLAG_HAS_CONTENT 1
#define FLAG_VALUE_ALLOCATED 2

#define FLAG_SET(bitmap,flag) (bitmap & flag)
#define FLAG_OFF(bitmap,flag) bitmap ^= flag
#define FLAG_ON(bitmap,flag) bitmap |= flag

#defeval HAS_CONTENT(node) FLAG_SET(node.flags,FLAG_HAS_CONTENT)
#defeval HAS_CONTENT_ON(node) FLAG_ON(node.flags,FLAG_HAS_CONTENT)
#defeval HAS_CONTENT_OFF(node) FLAG_OFF(node.flags,FLAG_HAS_CONTENT)

#define LENGTH() self._len
#define ROOT() self._root

#define LENGTH_UP() LENGTH += 1
#define LENGTH_DOWN() LENGTH -= 1



	
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
		
		cdef BOOL break_it = False 
		cdef int i, j
		
		cdef CONTENT_MAP_TYPE mask
		
		current_node._traversing.last_chunk = 0
		current_node._traversing.last_bit = 0
		
		# Clears the parent node record
		
		cdef NodePosition *pn_info = &(node.parent)
		cdef Node *parent_node = pn_info.node
		
		if pn_info.node:
			parent_node.subnodes_count -= 1
			
			if parent_node.subnodes_count <= 0:
				free(parent_node.subnodes[pn_info.chunk])
				parent_node.content_map = 0
			else:
				parent_node.subnodes[pn_info.chunk][pn_info.bit] = NULL
			
		# Do
		
		while current_node != node.parent.node:

			# Traversing
			while current_node.content_map:
				
				for i in range(current_node._traversing.last_chunk, CHUNKS_COUNT):
					
					mask = 1 << i
					if current_node.content_map & mask:
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
			
			self._dealloc_leaf_node(deallocated_node)
			
			
	cdef inline BOOL _dealloc_leaf_node(Trie self, Node *node):
		cdef BOOL result
		
		if node.content_map == 0:
			if HAS_CONTENT(node):
				LENGTH_DOWN()
				free(node.value)
			
			free(node)
			result = True
			
		else:
			result = False
			
		return result
		
	#define CREATE_NODE(output, _) \
_		output = <Node *> malloc(sizeof(Node)) \
_		output.content_map = 0 \
_		output.subnodes_count = 0 \
_		output.flags = 0	
			
	cdef inline Node* _create_node(Trie self):
		cdef Node *new_node
		
		CREATE_NODE(new_node)
		new_node.parent.node = NULL
		
		return new_node
	
	#define GET_SUBNODE_VARS(node) \
		cdef int _get_subnode__chunk
		
	#define GET_SUBNODE(output, node, position, _) \
_		if node.content_map: \
_			_get_subnode__chunk = (position & CHUNK_IDENTIFICATION_MASK) >> CHUNK_IDENTIFICATION_ALIGNMENT \
_			\
_			if node.content_map & (1 << _get_subnode__chunk): \
_				output = node.subnodes[_get_subnode__chunk][position & BIT_POSITION_MASK] \
_			else: \
_				output = NULL \
_		else: \
_			output = NULL
	
	cdef inline Node* _find_node(Trie self, char *key):
		
		cdef Node *current_node = ROOT()		
		cdef int length = strlen(key)
		cdef int i
		
		GET_SUBNODE_VARS()
		
		for i in range(0, length):
			GET_SUBNODE(current_node, current_node, key[i],	)
			
			if current_node == NULL:
				break
			
		return current_node
		
	cdef inline void _cut_node(Trie self, Node *node):
		
		"""
		Go around the tree non-recursive alghorithm.
		"""

		cdef Node *current_node = node
		cdef Node *processed_node
		
		cdef BOOL break_it = False 
		cdef int i, j
		
		cdef CONTENT_MAP_TYPE mask
		
		current_node._traversing.last_chunk = 0
		current_node._traversing.last_bit = 0
		current_node._traversing.content_map = current_node.content_map
		
		# Do
		
		while current_node != node.parent.node:

			# Traversing
			while current_node._traversing.content_map:
				
				for i in range(current_node._traversing.last_chunk, CHUNKS_COUNT):
					
					mask = 1 << i
					if current_node._traversing.content_map & mask:
						for j in range(current_node._traversing.last_bit, CHUNK_SIZE):
							processed_node = current_node.subnodes[i][j]

							if processed_node:
								current_node._traversing.last_chunk = i
								current_node._traversing.last_bit = j + 1
								
								processed_node._traversing.last_chunk = 0
								processed_node._traversing.last_bit = 0	
								processed_node._traversing.content_map = processed_node.content_map
								
								###
								
								# Deallocating the node content
								if HAS_CONTENT(processed_node):
									LENGTH_DOWN()
									HAS_CONTENT_OFF(processed_node)
								
								###
								
								current_node = processed_node
								
								break_it = True
								break
							
						if break_it:
							break_it = False
							break
					
						current_node._traversing.content_map = current_node._traversing.content_map ^ mask
			
			
			current_node = current_node.parent.node
		
	#define WRITE_SUBNODE_VARS() \
		cdef int _write_subnode__chunk \
		cdef int _write_subnode__bit \
		\
		cdef CONTENT_MAP_TYPE _write_subnode__mask 

	#define WRITE_SUBNODE(_node, _subnode, _position, _) \
_		_write_subnode__chunk = ((_position & CHUNK_IDENTIFICATION_MASK) >> CHUNK_IDENTIFICATION_ALIGNMENT) \
_		_write_subnode__bit = _position & BIT_POSITION_MASK \
_		\
_		_write_subnode__mask = 1 << _write_subnode__chunk \
_		\
_		if not (_node.content_map & _write_subnode__mask): \
_			_node.subnodes[_write_subnode__chunk] = <Node**> malloc(sizeof(Node *) * CHUNK_SIZE) \
_			memset(_node.subnodes[_write_subnode__chunk], 0, sizeof(Node *) * CHUNK_SIZE) \
_		\
_		_node.content_map = _node.content_map | _write_subnode__mask \
_		_node.subnodes[_write_subnode__chunk][_write_subnode__bit] = _subnode \
_		_node.subnodes_count += 1 \
_		\
_		_subnode.parent.node = _node \
_		_subnode.parent.chunk = _write_subnode__chunk \
_		_subnode.parent.bit = _write_subnode__bit

	cdef inline void __write_subnode(Trie self, Node *node, Node *subnode, char position):
		
		"""
		From an uknown reason, code with this inactive method is faster.
		"""
		
		WRITE_SUBNODE_VARS()
		WRITE_SUBNODE(node,subnode,position)	
	
	cdef inline void _add(Trie self, char *key, char *value):
		
		cdef char character
		cdef Node *working_node
		cdef int i
		cdef BOOL new_node_written = False
		
		cdef Node *current_node = ROOT()
		cdef int length = strlen(key)	
		
		GET_SUBNODE_VARS()
		WRITE_SUBNODE_VARS()
		
		for i in range(0, length):
			
			character = key[i]
			GET_SUBNODE(working_node, current_node, character,	)
			
			if working_node == NULL:				
				CREATE_NODE(working_node,		)
				WRITE_SUBNODE(current_node,working_node,character,		)
				new_node_written = True
			
			current_node = working_node
		
		current_node.value = value
		HAS_CONTENT_ON(current_node)
		
		if new_node_written:
			LENGTH_UP()
		
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
		
	cpdef get(Trie self, char *key):
		
		cdef Node *node = self._find_node(key)
		
		if node == NULL:
			raise KeyError
		
		if HAS_CONTENT(node):
			return node.value
		else:
			raise KeyError
		
	cpdef has_key(Trie self, char *key):
		
		if self._find_node(key):
			return True
		else:
			return False
	
	cpdef remove(Trie self, char *key):
		cdef Node *node = self._find_node(key)
		
		if node:
			HAS_CONTENT_OFF(node)
			LENGTH_DOWN()
	
	def remove_clean(Trie self, char *key):
		cdef Node *node = self._find_node(key)
		cdef Node *parent_node
		
		if node:
			if node.subnodes_count > 0:
				HAS_CONTENT_OFF(node)
			
			else:
				parent_node = node.parent.node
				
				while True:
					
					if (parent_node == NULL) or (parent_node.subnodes_count > 1) or HAS_CONTENT(parent_node):
						self._dealloc_leaf_node(node)
						break
						
					else:   
						free(parent_node.subnodes[node.parent.chunk])
						parent_node.content_map = 0
						
						self._dealloc_leaf_node(node)
						
						node = parent_node
						parent_node = node.parent.node
						
			LENGTH_DOWN()
						
			
	def cut(Trie self, char *mask):
		cdef Node *node = self._find_node(mask)
		
		if node:
			self._cut_node(node)
	
	def cut_clean(Trie self, char *mask):
		cdef Node *node = self._find_node(mask)
		
		if node:
			self._dealloc_node(node)
	
	def clean(Trie self):
		
		"""
		Go around the tree non-recursive alghorithm.
		"""

		cdef Node *current_node = ROOT()
		cdef Node *processed_node
		cdef Node *parent_node
		
		cdef BOOL break_it = False 
		cdef int i, j
		
		cdef CONTENT_MAP_TYPE mask
		
		current_node._traversing.last_chunk = 0
		current_node._traversing.last_bit = 0
		current_node._traversing.content_map = current_node.content_map
		
		# Do
		
		while current_node != self._root.parent.node:

			# Traversing
			while current_node._traversing.content_map:
				
				for i in range(current_node._traversing.last_chunk, CHUNKS_COUNT):
					
					mask = 1 << i
					if current_node._traversing.content_map & mask:
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
			parent_node = current_node.parent.node
			
			if (not HAS_CONTENT(current_node)) and ((parent_node and (parent_node.subnodes_count <= 0)) or (parent_node == NULL)):
				
				while True:
					
					if (parent_node == NULL) or (parent_node.subnodes_count > 1) or HAS_CONTENT(parent_node):
						self._dealloc_leaf_node(current_node)
						break
						
					else:   
						free(parent_node.subnodes[current_node.parent.chunk])
						parent_node.content_map = 0
						
						self._dealloc_leaf_node(current_node)
						
						current_node = parent_node
						parent_node = current_node.parent.node
						
				LENGTH_DOWN()
			
			current_node = parent_node
			
	def clear(Trie self):
		self._dealloc_node(self._root)
		self._root = self._create_node()
		
	def values(Trie self):
		
		"""
		Go around the tree non-recursive alghorithm.
		"""

		cdef Node *current_node = ROOT()
		cdef Node *processed_node
		
		cdef BOOL break_it = False 
		cdef int i, j
		
		cdef CONTENT_MAP_TYPE mask
		cdef list result = []
		
		current_node._traversing.last_chunk = 0
		current_node._traversing.last_bit = 0
		current_node._traversing.content_map = current_node.content_map
		
		# Do
		
		while current_node != self._root.parent.node:

			# Traversing
			while current_node._traversing.content_map:
				
				for i in range(current_node._traversing.last_chunk, CHUNKS_COUNT):
					
					mask = 1 << i
					if current_node._traversing.content_map & mask:
						for j in range(current_node._traversing.last_bit, CHUNK_SIZE):
							processed_node = current_node.subnodes[i][j]

							if processed_node:
								current_node._traversing.last_chunk = i
								current_node._traversing.last_bit = j + 1
								
								processed_node._traversing.last_chunk = 0
								processed_node._traversing.last_bit = 0	
								processed_node._traversing.content_map = processed_node.content_map
								
								# Checking the node content out
								if HAS_CONTENT(processed_node):
									result.append(processed_node.value)
									
								###
								
								current_node = processed_node
								
								break_it = True
								break
							
						if break_it:
							break_it = False
							break
					
						current_node._traversing.content_map = current_node._traversing.content_map ^ mask
			
			current_node = current_node.parent.node

		return result

		
	def keys(Trie self):
		
		"""
		Go around the tree non-recursive alghorithm.
		"""

		cdef Node *current_node = ROOT()
		cdef Node *processed_node
		
		cdef BOOL break_it = False 
		cdef int i, j
		
		cdef CONTENT_MAP_TYPE mask
		cdef list result = []
		
		cdef int level = 0
		cdef int max_level = 4
		cdef char *key_buffer = <char *> malloc(5 * sizeof(char))
		
		current_node._traversing.last_chunk = 0
		current_node._traversing.last_bit = 0
		current_node._traversing.content_map = current_node.content_map
		
		# Do
		
		while current_node != self._root.parent.node:

			# Traversing
			while current_node._traversing.content_map:
				
				for i in range(current_node._traversing.last_chunk, CHUNKS_COUNT):
					
					mask = 1 << i
					if current_node._traversing.content_map & mask:
						for j in range(current_node._traversing.last_bit, CHUNK_SIZE):
							processed_node = current_node.subnodes[i][j]

							if processed_node:
								current_node._traversing.last_chunk = i
								current_node._traversing.last_bit = j + 1
								
								processed_node._traversing.last_chunk = 0
								processed_node._traversing.last_bit = 0	
								processed_node._traversing.content_map = processed_node.content_map
								
								if level > max_level:
									max_level = level
									key_buffer = <char *> realloc(key_buffer, (max_level + 2) * sizeof(char))
									
								key_buffer[level] = i * CHUNK_SIZE + j
								level += 1
								
								# Checking the node content out
								if HAS_CONTENT(processed_node):
									key_buffer[level] = 0
									result.append(key_buffer)
									
								###
								
								current_node = processed_node
									
								break_it = True								
								break
							
						if break_it:
							break_it = False
							break
					
						current_node._traversing.content_map = current_node._traversing.content_map ^ mask
			
			current_node = current_node.parent.node
			level -= 1
		
		free(key_buffer)
		return result
		
		
	def items(Trie self):
		
		"""
		Go around the tree non-recursive alghorithm.
		"""

		cdef Node *current_node = ROOT()
		cdef Node *processed_node
		
		cdef BOOL break_it = False 
		cdef int i, j
		
		cdef CONTENT_MAP_TYPE mask
		cdef list result = []
		cdef tuple item
		
		cdef int level = 0
		cdef int max_level = 4
		cdef char *key_buffer = <char *> malloc(5 * sizeof(char))
		
		current_node._traversing.last_chunk = 0
		current_node._traversing.last_bit = 0
		current_node._traversing.content_map = current_node.content_map
		
		# Do
		
		while current_node != self._root.parent.node:

			# Traversing
			while current_node._traversing.content_map:
				
				for i in range(current_node._traversing.last_chunk, CHUNKS_COUNT):
					
					mask = 1 << i
					if current_node._traversing.content_map & mask:
						for j in range(current_node._traversing.last_bit, CHUNK_SIZE):
							processed_node = current_node.subnodes[i][j]
							
							if processed_node:
								current_node._traversing.last_chunk = i
								current_node._traversing.last_bit = j + 1
								
								processed_node._traversing.last_chunk = 0
								processed_node._traversing.last_bit = 0	
								processed_node._traversing.content_map = processed_node.content_map
								
								if level > max_level:
									max_level = level
									key_buffer = <char *> realloc(key_buffer, (max_level + 2) * sizeof(char))
									
								key_buffer[level] = i * CHUNK_SIZE + j
								level += 1
								
								# Checking the node content out
								if HAS_CONTENT(processed_node):
									key_buffer[level] = 0
									item = (key_buffer, processed_node.value)
									result.append(item)
								
								###
								
								current_node = processed_node
									
								break_it = True
								break
							
						if break_it:
							break_it = False
							break
							
						current_node._traversing.content_map = current_node._traversing.content_map ^ mask
						
			
			current_node = current_node.parent.node
			level -= 1
		
		free(key_buffer)
		return result
		
		
	def dictionary(Trie self):
		
		"""
		Go around the tree non-recursive alghorithm.
		"""

		cdef Node *current_node = ROOT()
		cdef  Node *processed_node
		
		cdef BOOL break_it = False 
		cdef int i, j
		
		cdef CONTENT_MAP_TYPE mask
		cdef dict result = {}
		
		cdef int level = 0
		cdef int max_level = 4
		cdef char *key_buffer = <char *> malloc(5 * sizeof(char))
		
		current_node._traversing.last_chunk = 0
		current_node._traversing.last_bit = 0
		current_node._traversing.content_map = current_node.content_map
		
		# Do
		
		while current_node != self._root.parent.node:

			# Traversing
			while current_node._traversing.content_map:
				
				for i in range(current_node._traversing.last_chunk, CHUNKS_COUNT):
					
					mask = 1 << i
					if current_node._traversing.content_map & mask:
						for j in range(current_node._traversing.last_bit, CHUNK_SIZE):
							processed_node = current_node.subnodes[i][j]

							if processed_node:
								current_node._traversing.last_chunk = i
								current_node._traversing.last_bit = j + 1
								
								processed_node._traversing.last_chunk = 0
								processed_node._traversing.last_bit = 0	
								processed_node._traversing.content_map = processed_node.content_map
								
								if level > max_level:
									max_level = level
									key_buffer = <char *> realloc(key_buffer, (max_level + 2) * sizeof(char))
									
								key_buffer[level] = i * CHUNK_SIZE + j
								level += 1
								
								# Checking the node content out
								if HAS_CONTENT(processed_node):
									key_buffer[level] = 0
									result[key_buffer] = processed_node.value
								
								###
								
								current_node = processed_node
								
								break_it = True								
								break
							
						if break_it:
							break_it = False
							break
					
						current_node._traversing.content_map = current_node._traversing.content_map ^ mask
						
			
			current_node = current_node.parent.node
			level -= 1
		
		free(key_buffer)
		return result
		
		
	def update(Trie self, tuple other):
		self.add(other[0], other[1])
		
		
	def fromkeys(Trie self, seq, value = []):
		cdef int length = len(seq)
		cdef int i
		
		if len(value) == 0:
			for i in range(0, length):
				self.add(seq[i], seq[i])
		else:
			for i in range(0, length):
				
				try:
					self.add(seq[i], value[i])
				except KeyError:
					self.add(seq[i], seq[i])
					
					
	def setdefault(Trie self, char *key, char *default = ""):
		cdef Node *node = self._find_node(key)
		cdef char *result
		
		if node and HAS_CONTENT(node):
			result = node.value
		elif default != "":
			self.add(key, default)
			result = default
		else:
			self.add(key, key)
			result = key
			
		return result
		
	def copy(Trie self):
		
		"""
		Go around the tree non-recursive alghorithm.
		"""
		
		cdef Node *current_node = ROOT()
		cdef Node *processed_node
		
		cdef Node *target_current_node
		cdef Node *target_processed_node
		
		cdef BOOL break_it = False 
		cdef int i, j
		
		
		cdef CONTENT_MAP_TYPE mask
		cdef int node_copy_size = sizeof(current_node.subnodes_count) + sizeof(current_node.flags) + sizeof(current_node.content_map) + sizeof(current_node.parent) - sizeof(current_node.parent.node)
		cdef int value_copy_size
		
		cdef Trie result = Trie()
		result._len = LENGTH()
		
		target_current_node = result._root
		memcpy(&(target_current_node.subnodes_count), &(current_node.subnodes_count), node_copy_size)
		
		current_node._traversing.last_chunk = 0
		current_node._traversing.last_bit = 0
		current_node._traversing.content_map = current_node.content_map
		
		# Do
		
		while current_node != self._root.parent.node:

			# Traversing
			while current_node._traversing.content_map:
				
				for i in range(current_node._traversing.last_chunk, CHUNKS_COUNT):
					
					mask = 1 << i
					if current_node._traversing.content_map & mask:

						if i > target_current_node._traversing.last_chunk:
							target_current_node.subnodes[i] = <Node **> malloc(sizeof(Node *) * CHUNK_SIZE)
							memset(target_current_node.subnodes[i], 0, sizeof(Node *) * CHUNK_SIZE)
							target_current_node._traversing.last_chunk = i
							
						for j in range(current_node._traversing.last_bit, CHUNK_SIZE):
							processed_node = current_node.subnodes[i][j]

							if processed_node:
								current_node._traversing.last_chunk = i
								current_node._traversing.last_bit = j + 1
								
								processed_node._traversing.last_chunk = 0
								processed_node._traversing.last_bit = 0	
								processed_node._traversing.content_map = processed_node.content_map
								
								current_node = processed_node
								
								###
								
								target_processed_node = <Node *> malloc(sizeof(Node))
								target_processed_node.parent.node = target_current_node
								target_current_node.subnodes[i][j] = target_processed_node
								
								target_processed_node._traversing.last_chunk = 0
								
								memcpy(&(target_processed_node.subnodes_count), &(processed_node.subnodes_count), node_copy_size)
								
								if HAS_CONTENT(processed_node):
									value_copy_size = (strlen(processed_node.value)+ 1) * sizeof(char)
									target_processed_node.value = <char *> malloc(value_copy_size)
									memcpy(target_processed_node.value, processed_node.value, value_copy_size)
								
								target_current_node = target_processed_node
								
								###
								
								break_it = True
								break
							
						if break_it:
							break_it = False
							break
							
						current_node._traversing.content_map = current_node._traversing.content_map ^ mask
						
			
			current_node = current_node.parent.node
			target_current_node = target_current_node.parent.node
		
		return result
		
	cpdef insert(Trie self, Trie trie):
		
		"""
		Go around the tree non-recursive alghorithm.
		"""

		cdef Node *current_node = trie._root
		cdef Node *processed_node
		
		cdef BOOL break_it = False 
		cdef int i, j
		
		cdef CONTENT_MAP_TYPE mask
		
		cdef int level = 0
		cdef int max_level = 4
		cdef char *key_buffer = <char *> malloc(5 * sizeof(char))
		
		current_node._traversing.last_chunk = 0
		current_node._traversing.last_bit = 0
		current_node._traversing.content_map = current_node.content_map
		
		# Do
		
		while current_node != trie._root.parent.node:

			# Traversing
			while current_node._traversing.content_map:
				
				for i in range(current_node._traversing.last_chunk, CHUNKS_COUNT):
					
					mask = 1 << i
					if current_node._traversing.content_map & mask:
						for j in range(current_node._traversing.last_bit, CHUNK_SIZE):
							processed_node = current_node.subnodes[i][j]
							
							if processed_node:
								current_node._traversing.last_chunk = i
								current_node._traversing.last_bit = j + 1
								
								processed_node._traversing.last_chunk = 0
								processed_node._traversing.last_bit = 0	
								processed_node._traversing.content_map = processed_node.content_map
								
								
								if level > max_level:
									max_level = level
									key_buffer = <char *> realloc(key_buffer, (max_level + 2) * sizeof(char))
									
								key_buffer[level] = i * CHUNK_SIZE + j
								level += 1
								
								# Checking the node content out
								if HAS_CONTENT(processed_node):
									key_buffer[level] = 0
									self.add(key_buffer, processed_node.value)
								
								###
								
								current_node = processed_node
								
								break_it = True
								break
							
						if break_it:
							break_it = False
							break
					
						current_node._traversing.content_map = current_node._traversing.content_map ^ mask
						
			
			current_node = current_node.parent.node
			level -= 1
		
		free(key_buffer)
		
	def __add__(Trie x, Trie y):
		x.insert(y)
		return x
		
	def __iadd__(Trie self, Trie x):
		self.insert(x)
		return self
		
	def __len__(Trie self):
		return LENGTH()
		
	def __getitem__(Trie self, char *x):
		return self.get(x)
		
	def __setitem__(Trie self, char *x, char *y):
		self.add(x, y)
		
	def __delitem__(Trie self, char *x):
		self.remove(x)
		
	def __contains__(Trie self, char *x):
		return self.has_key(x)
		
	def __str__(Trie self):
		
		"""
		Go around the tree non-recursive alghorithm.
		"""

		cdef Node *current_node = ROOT()
		cdef Node *processed_node
		
		cdef BOOL break_it = False 
		cdef int i, j
		
		cdef CONTENT_MAP_TYPE mask
		
		cdef int level = 0
		cdef int max_level = 4
		cdef char *key_buffer = <char *> malloc(5 * sizeof(char))
		
		cdef int buffer_chunk_size = LENGTH() * sizeof(char) * 16
		cdef int buffer_size = buffer_chunk_size + (3 * sizeof(char))
		cdef char *result_buffer = <char *> malloc(buffer_size)
		cdef char *result_buffer_head = result_buffer + sizeof(char)
		cdef char *result_buffer_tail = result_buffer + buffer_size
		
		result_buffer[0] = '{'
		
		cdef int key_length
		cdef int value_length
		cdef int length
		
		cdef char *new_buffer
		
		current_node._traversing.last_chunk = 0
		current_node._traversing.last_bit = 0
		current_node._traversing.content_map = current_node.content_map
		
		# Do
		
		while current_node != self._root.parent.node:

			# Traversing
			while current_node._traversing.content_map:
				
				for i in range(current_node._traversing.last_chunk, CHUNKS_COUNT):
					
					mask = 1 << i
					if current_node._traversing.content_map & mask:
						for j in range(current_node._traversing.last_bit, CHUNK_SIZE):
							processed_node = current_node.subnodes[i][j]
							
							if processed_node:
								current_node._traversing.last_chunk = i
								current_node._traversing.last_bit = j + 1
								
								processed_node._traversing.last_chunk = 0
								processed_node._traversing.last_bit = 0	
								processed_node._traversing.content_map = processed_node.content_map
								
								if level > max_level:
									max_level = level
									key_buffer = <char *> realloc(key_buffer, (max_level + 2) * sizeof(char))
									
								key_buffer[level] = i * CHUNK_SIZE + j
								level += 1
								
								###
								
								# Checking the node content out
								if HAS_CONTENT(processed_node):
									
									# Terminates key buffer
									key_buffer[level] = 0
									
									# Checks the current buffer size and eventually realloc the memory
									key_length = strlen(key_buffer)
									value_length = strlen(processed_node.value)
									
									length = 8 * sizeof(char) + key_length * sizeof(char) + value_length * sizeof(char)
									
									if result_buffer_head + length >= result_buffer_tail:
										buffer_size += buffer_chunk_size
										new_buffer = <char *> realloc(result_buffer, buffer_size)
										result_buffer_tail = new_buffer + buffer_size
										
										if new_buffer != result_buffer:
											result_buffer_head = new_buffer + (result_buffer_head - result_buffer)
											result_buffer = new_buffer
									
									# Joins to the result buffer
									
									result_buffer_head[0] = "'"
									result_buffer_head += sizeof(char)
									
									strncpy(result_buffer_head, key_buffer, key_length)
									result_buffer_head += key_length * sizeof(char)
									
									result_buffer_head[0] = "'"
									result_buffer_head[1] = ":"
									result_buffer_head[2] = " "
									result_buffer_head[3] = "'"
									result_buffer_head += sizeof(char) * 4
									
									strncpy(result_buffer_head, processed_node.value, value_length)
									result_buffer_head += value_length * sizeof(char)
									
									result_buffer_head[0] = "'"
									result_buffer_head[1] = ","
									result_buffer_head[2] = " "
									result_buffer_head += sizeof(char) * 3
									
								###
								
								current_node = processed_node
								
								break_it = True
								break
							
						if break_it:
							break_it = False
							break
					
						current_node._traversing.content_map = current_node._traversing.content_map ^ mask
						

			current_node = current_node.parent.node
			level -= 1
		
		free(key_buffer)
		
		result_buffer_head -= 2 * sizeof(char)
		result_buffer_head[0] = "}"
		result_buffer_head[1] = 0
		
		result_buffer = <char *> realloc(result_buffer, result_buffer_head - result_buffer + sizeof(char))
		return result_buffer
