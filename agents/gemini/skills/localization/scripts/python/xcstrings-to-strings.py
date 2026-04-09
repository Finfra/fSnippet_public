#!/usr/bin/env python3
"""
xcstrings 파일을 언어별 .lproj/xxx.strings 파일로 변환하는 스크립트
"""
import json
import os
import sys

# 언어 코드 -> lproj 폴더명 매핑
LANG_MAP = {
    'en': 'en',
    'ko': 'ko',
    'ja': 'ja',
    'de': 'de',
    'es': 'es',
    'fr': 'fr',
    'zh-Hans': 'zh-Hans',
    'zh-Hant': 'zh-Hant'
}

def escape_string(s):
    """strings 파일용 문자열 이스케이프"""
    if s is None:
        return ""
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\t', '\\t')

def xcstrings_to_strings(xcstrings_path, output_dir):
    """xcstrings 파일을 언어별 .strings 파일로 변환"""

    # 파일명 추출 (확장자 제외)
    base_name = os.path.splitext(os.path.basename(xcstrings_path))[0]

    # xcstrings 파일 읽기
    with open(xcstrings_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    source_lang = data.get('sourceLanguage', 'en')
    strings = data.get('strings', {})

    # 언어별 문자열 수집
    lang_strings = {lang: {} for lang in LANG_MAP.keys()}

    for key, entry in strings.items():
        localizations = entry.get('localizations', {})

        for lang in LANG_MAP.keys():
            if lang in localizations:
                loc_data = localizations[lang]
                string_unit = loc_data.get('stringUnit', {})
                value = string_unit.get('value')
                state = string_unit.get('state', 'new')

                # translated 상태인 것만 포함, 또는 값이 있으면 포함
                if value and state == 'translated':
                    lang_strings[lang][key] = value
                elif value and state == 'new':
                    # new 상태여도 값이 있으면 포함 (번역 필요 표시용)
                    lang_strings[lang][key] = value
            else:
                # 해당 언어에 localization이 없으면 키 자체를 값으로 사용 (source language인 경우)
                if lang == source_lang:
                    lang_strings[lang][key] = key

    # 각 언어별 .strings 파일 생성
    for lang, lang_folder in LANG_MAP.items():
        lproj_dir = os.path.join(output_dir, f'{lang_folder}.lproj')
        os.makedirs(lproj_dir, exist_ok=True)

        strings_file = os.path.join(lproj_dir, f'{base_name}.strings')

        with open(strings_file, 'w', encoding='utf-8') as f:
            f.write(f'/* {base_name}.strings ({lang}) */\n')
            f.write(f'/* Auto-generated from {base_name}.xcstrings */\n\n')

            # 키 정렬하여 작성
            for key in sorted(lang_strings[lang].keys()):
                value = lang_strings[lang][key]
                escaped_key = escape_string(key)
                escaped_value = escape_string(value)
                f.write(f'"{escaped_key}" = "{escaped_value}";\n')

        count = len(lang_strings[lang])
        print(f'  {lang_folder}.lproj/{base_name}.strings: {count} strings')

    return len(strings)

def main():
    resources_dir = 'fSnippet/fSnippet/Resources'

    xcstrings_files = [
        os.path.join(resources_dir, 'Localizable.xcstrings'),
        os.path.join(resources_dir, 'Settings.xcstrings')
    ]

    print('Converting xcstrings to .strings files...\n')

    for xcstrings_path in xcstrings_files:
        if os.path.exists(xcstrings_path):
            print(f'Processing: {os.path.basename(xcstrings_path)}')
            total = xcstrings_to_strings(xcstrings_path, resources_dir)
            print(f'  Total keys: {total}\n')
        else:
            print(f'File not found: {xcstrings_path}')

    print('Done!')
    print(f'\nOutput directory: {resources_dir}')
    print('\nNote: You may need to add these .lproj folders to your Xcode project.')

if __name__ == '__main__':
    main()
