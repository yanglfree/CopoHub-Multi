import os
import sys
from playwright.sync_api import sync_playwright

def capture_iap_images():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={'width': 1024, 'height': 4000})
        
        file_path = os.path.abspath('docs/iap_images.html')
        page.goto(f'file://{file_path}')
        
        # Wait for elements to be visible
        page.wait_for_selector('#monthly')
        
        # Capture each element
        output_dir = 'docs'
        os.makedirs(output_dir, exist_ok=True)
        
        for plan in ['monthly', 'yearly', 'lifetime']:
            element = page.locator(f'#{plan}')
            element.screenshot(path=f'{output_dir}/iap_{plan}.png')
            print(f'Captured {plan} image to {output_dir}/iap_{plan}.png')
            
        browser.close()

if __name__ == '__main__':
    capture_iap_images()
