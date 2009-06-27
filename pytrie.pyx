
cdef extern from "stdlib.h":
	void *malloc(size_t size)
	void free(void *ptr)
	
cdef extern from "string.h":
	size_t strlen(char *str)
	void* memset(void *buffer, int ch, size_t count)
	
cdef extern from "math.h":
	float ceil(float x)

#####

cdef struct Node:
	Node ***subnodes
	char *value
	unsigned long long *content_map

cdef class Trie:

	cdef Node* _root
	cdef int _long_long_int_ratio
	cdef int _node_content_map_reset_size
	
	def __cinit__(Trie self):
		self._long_long_int_ratio = sizeof(unsigned long long) / sizeof(unsigned int)
		self._node_content_map_reset_size = 4 * self._long_long_int_ratio
		self._root = self._create_node()
		
	def __dealloc__(Trie self):
		""""""
		
	cdef inline Node* _create_node(Trie self):

		cdef Node *new_node 		

		new_node = <Node *> malloc(sizeof(Node))
		new_node.value = ""
		
		new_node.subnodes = <Node ***> malloc(sizeof(Node **) * 4)
		
		new_node.content_map = <unsigned long long *> malloc(sizeof(unsigned long long) * 4)
		memset(new_node.content_map, 0, self._node_content_map_reset_size)
		
		return new_node
			
	cdef inline Node* _find_node(Trie self, char *key):
		
		cdef Node *current_node
		cdef int i, length
	
		current_node = self._root
		length = strlen(key) - 1

		for i in range(0, length):
			current_node = self._get_subnode(current_node, key[i])
			
			if current_node == NULL:		
				break
			
		return current_node
	

	cdef inline Node* _get_subnode(Trie self, Node *node, char position):
		
		cdef int chunk
		cdef int bit
		cdef unsigned long long mask
		cdef Node *result
		
		chunk = (position & 192) >> 6
		bit = position & 63
		mask = (<unsigned long long> 1) << bit

		if node.content_map[chunk] & mask:
			result = node.subnodes[chunk][bit]
		else:
			result = NULL
			
		return result
		
	cdef inline void _write_subnode(Trie self, Node *node, Node *subnode, char position):
		
		cdef int chunk
		cdef int bit
		cdef unsigned long long mask

		chunk = (position & 192) >> 6
		bit = position & 63
		mask = <unsigned long long> 1 << bit
		
		if node.content_map[chunk] == 0:
			node.subnodes[chunk] = <Node **> malloc(sizeof(Node *) * 64)
			
		node.content_map[chunk] = node.content_map[chunk] | mask
		node.subnodes[chunk][bit] = subnode
	
	
	cpdef add(Trie self, char *key, char *value):
		
		cdef unsigned char character
		cdef Node *current_node
		cdef Node *working_node	
		cdef int i, length
	
		current_node = self._root
		length = strlen(key) - 1		
		
		for i in range(0, length):
			
			character = key[i]
			working_node = self._get_subnode(current_node, character)
			
			if working_node == NULL:
				working_node = self._create_node()
				self._write_subnode(current_node, working_node, character)
				
			current_node = working_node
		
		current_node.value = value

	cpdef get(Trie self, char *key):
		
		cdef Node *node
		node = self._find_node(key)
		
		if node == NULL:
			raise KeyError
		
		return node.value


