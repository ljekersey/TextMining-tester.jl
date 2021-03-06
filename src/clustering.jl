#build q-matrix from a distance matrix m (nxn)
function qmake(m)
  n = size(m)[1]
  q = Array(Any,n,n)
  for i = 1:n
    for j = 1:n
      if j == i
        q[i,j] = 0
      else
        x = (n-2)*m[i,j]
        y = sum(m[i,:])-sum(m[j,:])
        q[i,j] = x-y
      end
    end
  end
  return q
end


#  find lowest value in a matrix q (nxn) and return its index
function nfind(q)
  n = size(q)[1]
  if n <= 1
    return nothing
  end
  lowest = q[1,2]
  lowestIndex = (1,2)
  for i = 1:n
    for j = 1:n
      current = q[i,j]
      if current != 0
        if current != NaN
          if current < lowest
            lowest = current
            lowestIndex = (i,j)
          end
        end
      end
    end
  end
  return lowestIndex
end


function hclust(fvectors,dist_func::Function=dist_euclidean, norm::Bool=true)
  if !isa(fvectors,Array)
    return nothing
  end
  tree = EmptyTree{Any,Any}()
  tree = setindex!(tree,1,"root")
  if length(fvectors) == 0
    b = BinaryTree{Any,Any}()
    return b
  end
  if length(fvectors) == 1
    tree.left = setindex!(tree.left,fvectors[1],"left")
    b = BinaryTree{Any,Any}()
    b.root = tree
    return b
  elseif length(fvectors) == 2
    tree.left = setindex!(tree.left,fvectors[1],"left")
    tree.right = setindex!(tree.right,fvectors[2],"right")
    b = BinaryTree{Any,Any}()
    b.root = tree
    return b
  end
  ind = 1
  data = Any[]
  append!(data,fvectors)
  while length(data) > 1
    ind = ind + 1
    #make an empty distance matrix
    d = Array(Any,length(data),length(data))
    fill!(d,0)
    # populate it with distances
    for i = 1:length(data)
      for j = 1:length(data)
        if isa(data[i],Cluster) && isa(data[j],Cluster)
          d[i,j] = dist_func(centroid(data[i]),centroid(data[j]),norm)
        elseif isa(data[i],FeatureVector) && isa(data[j],Cluster)
          d[i,j] = dist_func(data[i],centroid(data[j]),norm)
        elseif isa(data[i],Cluster) && isa(data[j],FeatureVector)
          d[i,j] = dist_func(centroid(data[i]),data[j],norm)
        elseif isa(data[i],FeatureVector) && isa(data[j],FeatureVector)
          d[i,j] = dist_func(data[i],data[j],norm)
        else
          continue
        end
      end
    end
    q = Any
    p = Any
    if length(data) >= 3
      q = qmake(d)
      p = nfind(q)
    else
      p = (1,2)
    end
    if p == nothing
      return nothing
    end
    u = Any
    # merge neighbors into u
    if isa(data[p[1]],FeatureVector) && isa(data[p[2]],FeatureVector)
      u = Cluster()
      u["v1"] = data[p[1]]
      u["v2"] = data[p[2]]
    else
      u = EmptyTree{Any,Any}()
      u = setindex!(u,ind,"node")
      u.left = setindex!(u.left,data[p[1]],"left")
      u.right = setindex!(u.right,data[p[2]],"right")
    end

# push u onto data
    push!(data,u)
    if p[1] > p[2]
      splice!(data,p[1])
      splice!(data,p[2])
    else
      splice!(data,p[2])
      splice!(data,p[1])
    end
  end
  if length(data) == 1
    b = BinaryTree{Any,Any}()
    b.root = data[1]
    return b
  end
  return nothing
end


function random_init(features,k)
  features = shuffle!(features)
  centroids = Array(FeatureVector,k)
  while k > 0
    centroids[k] = features[k]
    k-=1
  end
  return centroids
end
random_init(features,k,dist_func,norm::Bool=true) = random_init(features,k)


function max_min_init(features,k,dist_func,norm::Bool=true)
  rand_num = (abs(rand(Int64)%Base.length(features)) + 1)
  orig_cent = features[rand_num]
  centroids = vcat(orig_cent)
  cents_to_be_found = k-1
  while cents_to_be_found > 0
    max_min_dist = 0
    next_cent = FeatureVector()
    for fv in features
      min_dist = Inf
      for centroid in centroids
        cent_dist = dist_func(centroid,fv,norm)
        if cent_dist < min_dist
          min_dist = cent_dist
        end
      end
      if min_dist > max_min_dist
        max_min_dist = min_dist
        next_cent = fv
      end
    end
    centroids = vcat(centroids,next_cent)
    cents_to_be_found -= 1
  end
  return centroids
end

function kmeans(clust::Dict, cents::Array=[], k=iceil(sqrt(length(clust)/2)), init_cent_func=max_min_init, dist_func::Function=dist_euclidean, norm::Bool=true, max_iter::Integer=10000)
  # find initial k centroids
  features = collect(Base.values(clust))
  clust_keys = collect(Base.keys(clust))

  j = 1
  if k == 1
    single_clust = Cluster()
    for fv in features
      single_clust[clust_keys[j]] = fv
      j += 1
    end
    return [single_clust]
  end
  
  # check if user sent in own array of centroids
  if Base.length(cents) == 0
    centroids = init_cent_func(features,k,dist_func,norm)
  else
    centroids = cents
    length_array = Base.length(centroids)
    if k > length_array
      Base.warn("The k($k) you entered is bigger than the amount of centroids in the array, reverting k to $length_array")
    end
  end

  # make Array of k clusters
  new_clusters = []
  for centroid in centroids
    new_clusters = vcat(new_clusters, Cluster())
  end

  # find distance between fv and centroid
  iteration = 1
  changed = true
  while changed && iteration < max_iter
    println("Start iteration: $iteration")
    i = 1
    for fv in features
      dist = Inf
      j = 1
      min_dist_cluster = Cluster()
      for cluster in new_clusters
        current_dist = dist_func(centroids[j],fv,norm)
        if current_dist < dist
          dist = current_dist
          min_dist_cluster = cluster
        end
        j += 1
      end
      min_dist_cluster[clust_keys[i]] = fv
      i+=1
    end

    # recompute new centroids
    old_centroids = centroids
    new_centroids = Array(Any,length(centroids))
    x = 1
    for cluster in new_clusters
      new_cent = centroid(cluster)
      new_centroids[x] = new_cent
      x+=1
    end		

    # checking if centroids moved.
    changed = false
    i = 1
    for centroid in old_centroids
      dist = dist_func(centroid,new_centroids[i],norm)
      if dist > .000001
        changed = true
        centroids = new_centroids
        break
      end
      i += 1
    end

    # reset clusters if there are no changed.
    if changed
      new_clusters = []
      for centroid in centroids
        new_clusters = vcat(new_clusters, Cluster())
      end
    end
    iteration += 1
  end

  return new_clusters
end 
kmeans(clust::Dict, k, init_cent_func, dist_func, norm) = kmeans(clust,[],k,init_cent_func,dist_func,norm)
kmeans(clust::Dict, k, init_cent_func, dist_func) = kmeans(clust,[],k,init_cent_func,dist_func)
kmeans(clust::Dict, k, init_cent_func) = kmeans(clust,[],k,init_cent_func)
kmeans(clust::Dict, k) = kmeans(clust,[],k)


function elbow_method(clust::Dict, low_bound, high_bound, dist_func::Function=dist_euclidean, norm::Bool=true)
  if high_bound > length(clust)
    k = high_bound
    high_bound = length(clust)
    Base.warn("The high_bound($k) you entered is bigger than the amount of centroids in the array, reverting k to $high_bound")
  end
  if low_bound < 1
    k = low_bound
    low_bound = 1
    Base.warn("The low_bound($k) you entered is bigger than the amount of centroids in the array, reverting k to $low_bound")
  end

  temp_low = copy(low_bound)
  distances = []
  elbow_array = []
  while temp_low <= high_bound
    println("Start Elbow cluster $temp_low")
    clusters = kmeans(clust,temp_low,max_min_init,dist_func,norm)
    avg_dist = 0
    for cluster in clusters
      avg_dist += dist_centroid(cluster, dist_func, norm)
    end
    distances = vcat(distances,(avg_dist/length(clusters)))
    elbow_array = vcat(elbow_array,(temp_low,(avg_dist/length(clusters))))
    temp_low += 1
  end
  println(scatterplot(collect(low_bound:high_bound),distances,sym='*'))

  return elbow_array
end