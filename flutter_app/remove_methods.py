import re

def remove_methods(filepath, methods):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    for method in methods:
        # Regex to match method signature and then use brace counting to remove body
        # E.g., `Widget _componentsPage() {`
        pattern = re.compile(r'(?:(?:Future<[\w\s<>]*>|Widget|String|List<[\w\s<>]*>|void|bool)\??\s+)?' + re.escape(method) + r'\s*\([^)]*\)\s*(?:async\s*)?{')
        match = pattern.search(content)
        if not match:
            # Maybe it's a getter or simple arrow function? Let's check arrow functions too.
            pattern_arrow = re.compile(r'(?:(?:Future<[\w\s<>]*>|Widget|String|List<[\w\s<>]*>|void|bool)\??\s+)?' + re.escape(method) + r'\s*\([^)]*\)\s*(?:async\s*)?=>[^;]+;')
            match_arrow = pattern_arrow.search(content)
            if match_arrow:
                content = content[:match_arrow.start()] + content[match_arrow.end():]
                continue
            else:
                print(f"Method {method} not found!")
                continue
        
        start_idx = match.start()
        body_start = match.end() - 1
        
        brace_count = 0
        end_idx = body_start
        for i in range(body_start, len(content)):
            if content[i] == '{':
                brace_count += 1
            elif content[i] == '}':
                brace_count -= 1
                if brace_count == 0:
                    end_idx = i + 1
                    break
        
        # also remove trailing whitespace
        while end_idx < len(content) and content[end_idx] in [' ', '\t', '\n', '\r']:
            end_idx += 1
            
        content = content[:start_idx] + content[end_idx:]

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

methods_to_remove = [
    '_componentsPage',
    '_componentSearchField',
    '_mobileComponentFilterButton',
    '_componentSliverList',
    '_componentThumbnailSliverGrid',
    '_componentThumbnailCard',
    '_componentTypeLocationLabel',
    '_componentFilterBar',
    '_addComponentPanel',
    '_createComponent',
    '_categoryIdForComponentType',
    '_categoryMatchKey',
    '_editComponent',
    '_showComponentDetails',
    '_componentDetailRow',
    '_selectExpiryDate',
    '_componentTypeDisplayName',
    '_formatComponentPrice'
]

remove_methods('lib/features/inventory_home.dart', methods_to_remove)

