import re
import sys

def transform_identifier(s):
    # 规则1: 不处理白名单标识符
    if s in ['GCC']:
        return s

    # 规则2: 如果以下划线结尾，删除结尾下划线并将首字母大写
    if s.endswith('_'):
        s = s[:-1]
        if s:  # 确保非空字符串
            s = s[0].upper() + s[1:]

    # 规则3: 如果标识符仅有一个字母且为大写，添加'y'
    if len(s) == 1 and s.isupper():
        s += 'y'

    # 规则4：如果标识符以T结尾且不包含下划线，添加'y'
    if s.endswith('T') and (not ('_' in s)):
        s += 'y'

    # 规则5: 如果以大写字母开头，添加下划线前缀
    if s and s[0].isupper():
        s = '_' + s

    return s

def usage():
    print("Usage: python uglify.py input_file output_file [-container]")
    sys.exit(1)

if __name__ == '__main__':
    if not(len(sys.argv) == 3 or len(sys.argv) == 4):
        usage()

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    container = False

    if (len(sys.argv) == 4):
        if (sys.argv[3] == '-container'):
            container = True
        else:
            usage()

    with open(input_file, 'r') as f:
        content = f.read()
    
    #步骤0: 处理警告
    content = content.replace('#pragma clang diagnostic push', '#pragma clang diagnostic push\n#pragma clang diagnostic ignored "-Wuser-defined-literals"')

    #步骤1: 处理out_of_range和length_error
    content = content.replace('throw ::std::out_of_range', '_Xout_of_range')
    content = content.replace('throw ::std::length_error', '_Xlength_error')

    #步骤2: 处理min和max
    content = content.replace('(::std::min)', '(_STD min)')
    content = content.replace('(::std::max)', '(_STD max)')
    content = content.replace('::std::min', '(_STD min)')
    content = content.replace('::std::max', '(_STD max)')

    #步骤3: 处理DEBUG宏
    content = content.replace('!defined(NDEBUG)', '(_MSVC_STL_HARDENING_OPTIONAL || _ITERATOR_DEBUG_LEVEL != 0)')
    content = content.replace('defined(NDEBUG)', '!(_MSVC_STL_HARDENING_OPTIONAL || _ITERATOR_DEBUG_LEVEL != 0)')

    #步骤4: 处理size_t字面量
    content = re.sub(r'(\d+)uz', r'::std::size_t(\1)', content)
    content = re.sub(r'(\d+)z', r'::std::ptrdiff_t(\1)', content)

    # 步骤5: 把所有::std::替换为_STD
    content = content.replace('::std::', ' _STD ')
    content = content.replace('std::', ' _STD ')
    content = content.replace('bizwen::', ' _STD ')
    content = content.replace('::bizwen::', ' _STD ')

    # 步骤6: 处理namespace
    content = content.replace('namespace std\n{', '_STD_BEGIN')
    content = content.replace('namespace bizwen\n{', '_STD_BEGIN')
    content = content.replace('namespace std {', '_STD_BEGIN')
    content = content.replace('namespace bizwen {', '_STD_BEGIN')
    content = content.replace('} // namespace bizwen', '_STD_END')
    content = content.replace('} // namespace std', '_STD_END')
    content = content.replace('bizwen', '_STD')

    # 步骤7 处理双引号字符串 - 用占位符替换并保存
    string_placeholders = []
    pattern_string = r'\"(?:[^\"\\]|\\.)*\"'  # 匹配双引号包裹的内容（包括转义字符）

    def replace_string(match):
        string_placeholders.append(match.group(0))
        return f'__STRING_PLACEHOLDER_{len(string_placeholders)-1}__'

    # 用占位符替换所有双引号字符串
    content_no_strings = re.sub(pattern_string, replace_string, content)

    # 步骤8: 处理单行注释和标识符
    lines = content_no_strings.split('\n')
    processed_lines = []

    for line in lines:
        # 检查是否为单行注释（忽略前导空格）
        if re.match(r'^\s*//', line):
            # 单行注释 - 直接保留原内容
            processed_lines.append(line)
            continue

        # 匹配并转换标识符
        pattern_identifier = r'\b[a-zA-Z][a-zA-Z0-9_]*\b'
        identifiers = set(re.findall(pattern_identifier, line))

        # 按长度降序排序，确保先替换长标识符
        sorted_identifiers = sorted(identifiers, key=len, reverse=True)

        # 创建替换映射
        replace_map = {}
        for identifier in sorted_identifiers:
            new_identifier = transform_identifier(identifier)
            if new_identifier != identifier:
                replace_map[identifier] = new_identifier

        # 执行替换
        for old, new in replace_map.items():
            line = re.sub(r'\b' + re.escape(old) + r'\b', new, line)

        processed_lines.append(line)

    # 重新组合内容
    content = '\n'.join(processed_lines)

    # 步骤9: 恢复双引号字符串
    for i, s in enumerate(string_placeholders):
        placeholder = f'__STRING_PLACEHOLDER_{i}__'
        content = content.replace(placeholder, s)

    # 步骤10: 将assert换为_STL_ASSERT
    content = re.sub(r'(?<!_)\bassert\((.*?)\);\n', r'#if ((_MSVC_STL_HARDENING_OPTIONAL || _ITERATOR_DEBUG_LEVEL != 0))\n_STL_ASSERT(\1, "assert: \1");\n#endif\n''', content)

    with open(output_file, 'w') as f:
        f.write(content)
