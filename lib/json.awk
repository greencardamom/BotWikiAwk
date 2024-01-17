#
#  query_json() and associate routines
#
#   From 'awkenough'
#
#	https://github.com/dubiousjim/awkenough
#
#   Copyright MIT license
#   Copyright (c) 2007-2011 Aleksey Cheusov <vle@gmx.net>
#   Copyright (c) 2012 Jim Pryor <dubiousjim@gmail.com>
#   Copyright (c) 2018-2024 GreenC (User:GreenC at en.wikipedia.org)
#

#
#  Sample usage
#
# 1. Create a sample JSON file eg. 
#    wget -q -O- "https://en.wikipedia.org/w/api.php?action=query&titles=Public opinion on global warming|Pertussis&prop=info&format=json&utf8=&redirects" > o
# 2. In a test, view what the json-array looks like with dump() eg.
#      awk -i json.awk -i readfile 'BEGIN{query_json(readfile("o"), jsona); awkenough_dump(jsona, "jsona")}'
# 3. Use the json-array in a program 
#      if( query_json(readfile("o"), jsona) >= 0)
#        id = jsona["query","pages","25428398","pageid"]
#

function awkenough_die(msg) {
    printf("awkenough: %s\n", msg) > "/dev/stderr"
    # exit 1
}

function awkenough_assert(test, msg) {
    if (!test) awenough_die(msg ? msg : "assertion failed")
}

# unitialized scalar
function ismissing(u) {
    return u == 0 && u == ""
}

# explicit ""
function isnull(s, u) {
    if (u) return s == "" # accept missing as well
    return !s && s != 0
}

# populate array from str="key key=value key=value"
# can optionally supply "re" for equals, space; if they're the same or equals is "", array will be setlike
function awkenough_asplit(str, array,  equals, space,   aux, i, n) {
    n = split(str, aux, (space == "") ? "[ \n]+" : space)
    if (space && equals == space)
        equals = ""
    else if (ismissing(equals))
        equals = "="
    split("", array) # delete array
    for (i=1; i<=n; i++) {
        if (equals && match(aux[i], equals))
            array[substr(aux[i], 1, RSTART-1)] = substr(aux[i], RSTART+RLENGTH)
        else
            array[aux[i]]
    }
    split("", aux) # does it help to delete the aux array?
    return n
}

# behaves like gawk's split; special cases re == "" and " "
# unlike split, will honor 0-length matches
function awkenough_gsplit(str, items, re,  seps,   n, i, start, stop, sep1, sep2, sepn) {
    n = 0
    # find separators that don't occur in str
    i = 1
    do
        sep1 = sprintf("%c", i++)
    while (index(str, sep1))
    do
        sep2 = sprintf("%c", i++)
    while (index(str, sep2))
    sepn = 1
    split("", seps) # delete array
    if (ismissing(re))
        re = FS
    if (re == "") {
        split(str, items, "")
        n = length(str)
        for (i=1; i<n; i++)
            seps[i]
        return n
    }
    split("", items) # delete array
    if (re == " ") {
        re = "[ \t\n]+"
        if (match(str, /^[ \t\n]+/)) {
            seps[0] = substr(str, 1, RLENGTH)
            str = substr(str, RLENGTH+1)
        }
        if (match(str, /[ \t\n]+$/)) {
            sepn = substr(str, RSTART, RLENGTH)
            str = substr(str, 1, RSTART-1)
        }
    }
    i = gsub(re, sep1 "&" sep2, str)
    while (i--) {
        start = index(str, sep1)
        stop = index(str, sep2) - 1
        seps[++n] = substr(str, start + 1, stop - start)
        items[n] = substr(str, 1, start - 1)
        str = substr(str, stop + 2)
    }
    items[++n] = str
    if (sepn != 1) seps[n] = sepn
    return n
}


function parse_json(str, T, V,  slack,    c,s,n,a,A,b,B,C,U,W,i,j,k,u,v,w,root) {
    # use strings, numbers, booleans as separators
    # c = "[^\"\\\\[:cntrl:]]|\\\\[\"\\\\/bfnrt]|\\u[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]"
    c = "[^\"\\\\\001-\037]|\\\\[\"\\\\/bfnrt]|\\\\u[[:xdigit:]A-F][[:xdigit:]A-F][[:xdigit:]A-F][[:xdigit:]A-F]"
    s ="\"(" c ")*\""
    n = "-?(0|[1-9][[:digit:]]*)([.][[:digit:]]+)?([eE][+-]?[[:digit:]]+)?"

    root = awkenough_gsplit(str, A, s "|" n "|true|false|null", T)
    awkenough_assert(root > 0, "unexpected")

    # rejoin string using value indices
    str = ""
    for (i=1; i<root; i++)
        str = str A[i] i
    str = str A[root]

    # cleanup types and values
    for (i=1; i<root; i++) {
        if (T[i] ~ /^"/) {
            b = split(substr(T[i], 2, length(T[i])-2), B, /\\/)
            if (b == 0) v = ""
            else {
                v = B[1]
                k = 0
                for (j=2; j <= b; j++) {
                    u = B[j]
                    if (u == "") {
                       if (++k % 2 == 1) v = v "\\"
                    } else {
                        w = substr(u, 1, 1)  
                        if (w == "b") v = v "\b" substr(u, 2)
                        else if (w == "f") v = v "\f" substr(u, 2)
                        else if (w == "n") v = v "\n" substr(u, 2)
                        else if (w == "r") v = v "\r" substr(u, 2)
                        else if (w == "t") v = v "\t" substr(u, 2)
                        else v = v u
                    }
                }
            }
            V[i] = v
            T[i] = "string"
        } else if (T[i] !~ /true|false|null/) {
            V[i] = T[i] + 0
            T[i] = "number"
        } else {
            V[i] = T[i]
        }
    }

    # sanitize string
    gsub(/[[:space:]]+/, "", str)
    if (str !~ /^[][{}[:digit:],:]+$/) {
        if (slack !~ /:/) return -1
        # handle ...unquoted:...
        a = awkenough_gsplit(str, A, "[[:alpha:]_][[:alnum:]_]*:", B)
        str = ""
        for (i=1; i < a; i++) {
            T[root] = "string"
            V[root] = substr(B[i], 1, length(B[i])-1)
            str = str A[i] root ":"
            root++
        }
        str = str A[a]
        if (str !~ /^[][{}[:digit:],:]+$/) return -10
    }

    # atomic value?
    a = awkenough_gsplit(str, A, "[[{]", B)
    if (A[1] != "") {
        if (a > 1) return -2
        else if (A[1] !~ /^[[:digit:]]+$/) return -3
        else return A[1]+0
    }

    # parse objects and arrays
    k = root
    C[0] = 0
    for (i=2; i<=a; i++) {
        T[k] = (B[i-1] ~ /\{/) ? "object" : "array"
        C[k] = C[0]
        C[0] = k
        u = awkenough_gsplit(A[i], U, "[]}]", W)
        awkenough_assert(u > 0, "unexpected")
        V[k++] = U[1]
        if (i < a && A[i] != "" && U[u] !~ /[,:]$/)
            return -4
        for (j=1; j<u; j++) {
            if (C[0] == 0 || T[C[0]] != ((W[j] == "}") ? "object" : "array")) return -5
            v = C[0]
            w = C[v]
            C[0] = w
            delete C[v]
            if (w) V[w] = V[w] v U[j+1]
        }
    }
    if (C[0] != 0) return -6

    # check contents
    for (i=root; i<k; i++) {
        if (T[i] == "object") {
            # check object contents
            b = split(V[i], B, /,/) 
            for (j=1; j <= b; j++) {
                if (B[j] !~ /^[[:digit:]]+:[[:digit:]]+$/)
                    return -7
                if (T[substr(B[j], 1, index(B[j],":")-1)] != "string")
                    return -8
            }
        } else if (V[i] != "") {
            # check array contents
            if (slack ~ /,/ && V[i] ~ /,$/)
                V[i] = substr(V[i], 1, length(V[i] -1))
            if (V[i] !~ /^[[:digit:]]+(,[[:digit:]]+)*$/)
                return -9
        }
    }
    return root
}

#
# Return a number < 0 on failure. Zero on success
#
function query_json(str, X,  root, slack,   T, V, A, B, C, i, j, k) {

    delete X
    k = parse_json(str, T, V, slack)
    if (k < 1) return k
    split(root, C, ".")
    j = 1
    while (j in C) {
        if (T[k] == "array")
            split(V[k], A, ",")
        else {
            split("", A)
            awkenough_asplit(V[k], B, ":", ",")
            for (i in B)
                A[V[i]] = B[i]
        }
        if (C[j] in A) {
            k = A[C[j]]
            j++
        } else return -11 # can't find requested root
    }
    # split("", B)
    # split("", C)
    split("", X)
    B[k] = ""
    C[k] = 0
    C[0] = k
    do {
        C[0] = C[k]
        delete C[k]
        j = T[k]
        if (j == "array") {
            j = split(V[k], A, ",")
            k = B[k] ? B[k] SUBSEP : ""
            X[k 0] = j
            for (i=1; i<=j; i++) {
               # push A[i] to C, (B[k],i) to B 
                C[A[i]] = C[0]
                B[A[i]] = k i
                C[0] = A[i]
            }
        } else if (j == "object") {
            awkenough_asplit(V[k], A, ":", ",")
            k = B[k] ? B[k] SUBSEP : ""
            for (i in A) {
                # push A[i] to C, (B[k],V[i]) to B 
                C[A[i]] = C[0]
                B[A[i]] = k V[i]
                C[0] = A[i]
            }
        } else if (j == "number") {
            X[B[k]] = V[k]
        } else if (j == "true") {
            X[B[k]] = 1
        } else if (j == "false") {
            X[B[k]] = 0
        } else if (j == "string") {
            X[B[k]] = V[k]
        } else {
            # null will satisfy ismissing()
            X[B[k]] 
        }
        k = C[0]
    } while (k)
    return 0
}

#
# Visually inspect array created by query_json()
#
# Credit: awkenough
#         GreenC
#
function awkenough_dump(array, prefix, i,j,c,a,k,s,sep) {

  for(i in array) {
    j = i
    c = split(i, a, SUBSEP, sep)
    for(k = 1; k <= length(sep); k++) {
      gsub(/\\/, "\\", sep[k])
      gsub(/\//, "\\/", sep[k])
      gsub(/\t/, "\\t", sep[k])
      gsub(/\n/, "\\n", sep[k])
      gsub(/\r/, "\\r", sep[k])
      gsub(/\b/, "\\b", sep[k])
      gsub(/\f/, "\\f", sep[k])
      gsub(SUBSEP, ",", sep[k])          
      gsub(/[\001-\037]/, "¿", sep[k])   # TODO: convert to octal?
    }

    s = ""
    for(k = 1; k <= c; k++) 
      s = s "\"" a[k] "\"" sep[k]
    printf "%s[%s]=%s\n", prefix, s, array[i]
  }
}

#
# Given a JSON-array (jsonarr) created by query_json() producing:
#
#    jsona["query","pages","4035","pageid"]=8978
#
# Populate arr[] such that:
#
#    splitja(jsonarr, arr, 3, "pageid") ==>  arr["4035"]=8978
#
# indexn is the field # counting from left=>right - this becomes the index of arr
# value is the far-right (last) field name of the record for which the 8978 is assigned to arr[]
# optional offset: instead of the far-right (last) field for value, move to left by offset
#   eg. to get the field "pages" in the above example, use an offset of 2 (count two fields left from "pageid")
# optional lasti: this is the last field eg. "pageid" - required if using offset                
#
# Credit: GreenC
#
function splitja(jsonarr, arr, indexn, value, offset, lasti,   c,ja,a) {
  delete arr
  for(ja in jsonarr) {
    c = split(ja, a, SUBSEP) 
    if(lasti && offset) {
      if(a[c-offset] == value && a[c] == lasti)  
        arr[a[indexn]] = jsonarr[ja]
    }
    else {
      if(a[c] == value)                          
        arr[a[indexn]] = jsonarr[ja]
    }               
  }
  return length(arr)   
}


