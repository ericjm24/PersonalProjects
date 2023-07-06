import ebooklib
from ebooklib import epub
from bs4 import BeautifulSoup
import os
from string import ascii_letters
from random import choices
from multiprocessing import Pool

def chapter_to_str(chapter):
    soup = BeautifulSoup(chapter.get_body_content(), 'html.parser')
    text = [para.get_text() for para in soup.find_all('p')]
    return ' '.join(text)

def ebook_to_text(args):
    filename = args[0]
    target_path = args[1]
    book = epub.read_epub(filename)
    items = list(book.get_items_of_type(ebooklib.ITEM_DOCUMENT))
    text = ' '.join(chapter_to_str(c) for c in items if 'chapter' in c.get_name().lower())
    with open(target_path, 'w') as f:
        f.write(text)

def make_dir_to_text(dir, target_dir):
    output = []
    for root, _, files in os.walk(dir):
        for file in files:
            if file.lower().endswith('.epub'):
                target_path = os.path.join(target_dir, os.path.basename(file))+'_'+''.join(choices(ascii_letters, k=5))+'.txt'
                output.append((os.path.join(root, file), target_path))
    return output

if __name__ == '__main__':
    dir = '/home/ericjm24/fimarch/epub'
    target_dir = '/home/ericjm24/fimarch/txt'
    args = make_dir_to_text(dir, target_dir)
    with Pool(8) as p:
        p.map(ebook_to_text, args)