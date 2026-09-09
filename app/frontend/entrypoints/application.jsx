import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import '@mantine/core/styles.css'

const router = createBrowserRouter([
  {
    path: '/',
    element: <h1>ERP Repostería + Gestión Ágil</h1>,
  },
])

createRoot(document.getElementById('app')).render(
  <StrictMode>
    <MantineProvider>
      <RouterProvider router={router} />
    </MantineProvider>
  </StrictMode>,
)